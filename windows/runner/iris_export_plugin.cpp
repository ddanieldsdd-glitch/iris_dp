#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <gdiplus.h>
#include <shellapi.h>
#include <memory>
#include <string>
#include <vector>

#pragma comment(lib, "gdiplus.lib")

// Portapapeles de imágenes en Windows, por el mismo canal que usa el Mac
// («com.iris_dp/export_file_saver»):
// - readClipboard: PNG, mapa de bits (cualquier profundidad), un archivo
//   copiado en el Explorador (como ruta) o el texto, para que pegar una URL
//   siga funcionando.
// - writeClipboardImage: copia una imagen de disco al portapapeles.

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;
using flutter::FlutterEngine;
using Result = std::unique_ptr<flutter::MethodResult<EncodableValue>>;

// GDI+ se arranca una vez y vive lo que la app: así ningún objeto suyo se
// destruye después de apagarlo.
void EnsureGdiplus() {
  static ULONG_PTR token = 0;
  if (token == 0) {
    Gdiplus::GdiplusStartupInput input;
    Gdiplus::GdiplusStartup(&token, &input, nullptr);
  }
}

std::string ToUtf8(const std::wstring& text) {
  if (text.empty()) return std::string();
  const int size = WideCharToMultiByte(CP_UTF8, 0, text.c_str(),
                                       static_cast<int>(text.size()), nullptr,
                                       0, nullptr, nullptr);
  std::string out(size, '\0');
  WideCharToMultiByte(CP_UTF8, 0, text.c_str(), static_cast<int>(text.size()),
                      out.data(), size, nullptr, nullptr);
  return out;
}

std::wstring FromUtf8(const std::string& text) {
  if (text.empty()) return std::wstring();
  const int size = MultiByteToWideChar(CP_UTF8, 0, text.c_str(),
                                       static_cast<int>(text.size()), nullptr, 0);
  std::wstring out(size, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, text.c_str(), static_cast<int>(text.size()),
                      out.data(), size);
  return out;
}

// El codificador de GDI+ para un tipo («image/png»). GDI+ no trae esta
// función: es la de la documentación de Microsoft.
bool EncoderClsid(const wchar_t* mime, CLSID* clsid) {
  UINT count = 0, size = 0;
  Gdiplus::GetImageEncodersSize(&count, &size);
  if (size == 0) return false;
  std::vector<BYTE> buffer(size);
  auto* encoders = reinterpret_cast<Gdiplus::ImageCodecInfo*>(buffer.data());
  Gdiplus::GetImageEncoders(count, size, encoders);
  for (UINT i = 0; i < count; ++i) {
    if (wcscmp(encoders[i].MimeType, mime) == 0) {
      *clsid = encoders[i].Clsid;
      return true;
    }
  }
  return false;
}

// Un Bitmap de GDI+ en PNG.
std::vector<uint8_t> EncodePng(Gdiplus::Bitmap& bitmap) {
  std::vector<uint8_t> bytes;
  CLSID png;
  if (!EncoderClsid(L"image/png", &png)) return bytes;
  IStream* stream = nullptr;
  if (FAILED(CreateStreamOnHGlobal(nullptr, TRUE, &stream)) || !stream) {
    return bytes;
  }
  if (bitmap.Save(stream, &png, nullptr) == Gdiplus::Ok) {
    STATSTG stat{};
    stream->Stat(&stat, STATFLAG_NONAME);
    const ULONG size = stat.cbSize.LowPart;
    bytes.resize(size);
    LARGE_INTEGER zero{};
    stream->Seek(zero, STREAM_SEEK_SET, nullptr);
    ULONG read = 0;
    stream->Read(bytes.data(), size, &read);
    bytes.resize(read);
  }
  stream->Release();
  return bytes;
}

EncodableValue ImageResult(const std::vector<uint8_t>& bytes,
                           const char* extension) {
  return EncodableValue(EncodableMap{
      {EncodableValue("kind"), EncodableValue("image")},
      {EncodableValue("bytes"), EncodableValue(bytes)},
      {EncodableValue("extension"), EncodableValue(extension)},
  });
}

EncodableValue KindResult(const char* kind, const std::string& key = "",
                          const std::string& value = "") {
  EncodableMap map{{EncodableValue("kind"), EncodableValue(kind)}};
  if (!key.empty()) map[EncodableValue(key)] = EncodableValue(value);
  return EncodableValue(map);
}

// PNG tal cual, como lo dejan los navegadores y Office.
bool ReadPng(EncodableValue* out) {
  const UINT format = RegisterClipboardFormatW(L"PNG");
  if (format == 0 || !IsClipboardFormatAvailable(format)) return false;
  HANDLE handle = GetClipboardData(format);
  if (!handle) return false;
  const SIZE_T size = GlobalSize(handle);
  const auto* data = static_cast<const uint8_t*>(GlobalLock(handle));
  if (!data || size == 0) return false;
  std::vector<uint8_t> bytes(data, data + size);
  GlobalUnlock(handle);
  *out = ImageResult(bytes, ".png");
  return true;
}

// Un mapa de bits (capturas, imágenes copiadas en casi cualquier programa).
// GDI+ lo lee con su cabecera: cualquier profundidad y de arriba abajo o al
// revés.
bool ReadDib(EncodableValue* out) {
  if (!IsClipboardFormatAvailable(CF_DIB)) return false;
  HANDLE handle = GetClipboardData(CF_DIB);
  if (!handle) return false;
  auto* info = static_cast<BITMAPINFO*>(GlobalLock(handle));
  if (!info) return false;
  const BITMAPINFOHEADER& header = info->bmiHeader;
  DWORD colors = header.biClrUsed;
  if (colors == 0 && header.biBitCount <= 8) colors = 1u << header.biBitCount;
  DWORD masks = 0;
  if (header.biCompression == BI_BITFIELDS && header.biSize == sizeof(BITMAPINFOHEADER)) {
    masks = 3 * sizeof(DWORD);
  }
  BYTE* bits = reinterpret_cast<BYTE*>(info) + header.biSize + masks +
               colors * sizeof(RGBQUAD);
  std::vector<uint8_t> bytes;
  {
    Gdiplus::Bitmap bitmap(info, bits);
    if (bitmap.GetLastStatus() == Gdiplus::Ok) bytes = EncodePng(bitmap);
  }
  GlobalUnlock(handle);
  if (bytes.empty()) return false;
  *out = ImageResult(bytes, ".png");
  return true;
}

// Un archivo copiado en el Explorador: su ruta, que la parte Dart lee si
// es una imagen (sin borrarla).
bool ReadDroppedFile(EncodableValue* out) {
  if (!IsClipboardFormatAvailable(CF_HDROP)) return false;
  auto drop = static_cast<HDROP>(GetClipboardData(CF_HDROP));
  if (!drop) return false;
  const UINT length = DragQueryFileW(drop, 0, nullptr, 0);
  if (length == 0) return false;
  std::wstring path(length, L'\0');
  DragQueryFileW(drop, 0, path.data(), length + 1);
  *out = KindResult("text", "text", ToUtf8(path));
  return true;
}

bool ReadText(EncodableValue* out) {
  if (!IsClipboardFormatAvailable(CF_UNICODETEXT)) return false;
  HANDLE handle = GetClipboardData(CF_UNICODETEXT);
  if (!handle) return false;
  const auto* text = static_cast<const wchar_t*>(GlobalLock(handle));
  if (!text) return false;
  std::wstring copy(text);
  GlobalUnlock(handle);
  *out = KindResult("text", "text", ToUtf8(copy));
  return true;
}

void ReadClipboard(Result result) {
  EnsureGdiplus();
  if (!OpenClipboard(nullptr)) {
    result->Success(KindResult("empty"));
    return;
  }
  EncodableValue value = KindResult("empty");
  if (!ReadPng(&value) && !ReadDib(&value) && !ReadDroppedFile(&value)) {
    ReadText(&value);
  }
  CloseClipboard();
  result->Success(value);
}

// Copia al portapapeles la imagen de un archivo (PNG, JPEG, BMP, GIF,
// TIFF). Windows ofrece a los demás programas el formato que pidan.
void WriteClipboardImage(const std::string& path, Result result) {
  EnsureGdiplus();
  HBITMAP hbitmap = nullptr;
  {
    Gdiplus::Bitmap bitmap(FromUtf8(path).c_str());
    if (bitmap.GetLastStatus() != Gdiplus::Ok ||
        bitmap.GetHBITMAP(Gdiplus::Color(255, 255, 255), &hbitmap) !=
            Gdiplus::Ok) {
      result->Success(EncodableValue(false));
      return;
    }
  }
  if (!OpenClipboard(nullptr)) {
    DeleteObject(hbitmap);
    result->Success(EncodableValue(false));
    return;
  }
  EmptyClipboard();
  const bool done = SetClipboardData(CF_BITMAP, hbitmap) != nullptr;
  CloseClipboard();
  // Si el portapapeles lo aceptó, ahora es suyo.
  if (!done) DeleteObject(hbitmap);
  result->Success(EncodableValue(done));
}

void Register(FlutterEngine* engine) {
  auto channel = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      engine->messenger(), "com.iris_dp/export_file_saver",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<EncodableValue>& call, Result result) {
        const std::string& name = call.method_name();
        if (name == "ping") {
          result->Success(EncodableValue(true));
        } else if (name == "readClipboard") {
          ReadClipboard(std::move(result));
        } else if (name == "writeClipboardImage") {
          const auto* args = std::get_if<EncodableMap>(call.arguments());
          std::string path;
          if (args) {
            auto it = args->find(EncodableValue("path"));
            if (it != args->end()) {
              if (const auto* s = std::get_if<std::string>(&it->second)) {
                path = *s;
              }
            }
          }
          if (path.empty()) {
            result->Success(EncodableValue(false));
          } else {
            WriteClipboardImage(path, std::move(result));
          }
        } else {
          result->NotImplemented();
        }
      });

  // El canal vive lo que la app.
  static auto* channel_ptr = channel.release();
  (void)channel_ptr;
}

}  // namespace

void RegisterIrisExportPlugin(FlutterEngine* engine) {
  Register(engine);
}
