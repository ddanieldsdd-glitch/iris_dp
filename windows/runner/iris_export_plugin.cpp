#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <gdiplus.h>
#include <memory>
#include <vector>

#pragma comment(lib, "gdiplus.lib")

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;
using flutter::FlutterEngine;

class IrisExportPlugin {
 public:
  static void Register(FlutterEngine* engine) {
    auto channel =
        std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            engine->messenger(), "com.iris_dp/export_file_saver",
            &flutter::StandardMethodCodec::GetInstance());

    channel->SetMethodCallHandler(
        [](const flutter::MethodCall<flutter::EncodableValue>& call,
           std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
          if (call.method_name() == "readClipboard") {
            ReadClipboard(std::move(result));
          } else {
            result->NotImplemented();
          }
        });

    static auto* channel_ptr = channel.release();
    (void)channel_ptr;
  }

 private:
  static void ReadClipboard(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    if (!OpenClipboard(nullptr)) {
      result->Success(EncodableMap{{EncodableValue("kind"), EncodableValue("empty")}});
      return;
    }

    HANDLE handle = GetClipboardData(CF_DIB);
    if (handle == nullptr) {
      CloseClipboard();
      result->Success(EncodableMap{{EncodableValue("kind"), EncodableValue("empty")}});
      return;
    }

    BITMAPINFOHEADER* bmi = static_cast<BITMAPINFOHEADER*>(GlobalLock(handle));
    if (bmi == nullptr) {
      CloseClipboard();
      result->Success(EncodableMap{{EncodableValue("kind"), EncodableValue("empty")}});
      return;
    }

    ULONG_PTR gdiplusToken;
    Gdiplus::GdiplusStartupInput gdiplusStartupInput;
    Gdiplus::GdiplusStartup(&gdiplusToken, &gdiplusStartupInput, nullptr);

    const int width = bmi->biWidth;
    const int height = abs(bmi->biHeight);
    Gdiplus::Bitmap bitmap(width, height, PixelFormat32bppARGB);
    Gdiplus::Graphics graphics(&bitmap);
    HDC hdc = GetDC(nullptr);
    HDC memDC = CreateCompatibleDC(hdc);
    HBITMAP hBitmap = CreateCompatibleBitmap(hdc, width, height);
    SelectObject(memDC, hBitmap);

    BITMAPINFO bi{};
    bi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bi.bmiHeader.biWidth = width;
    bi.bmiHeader.biHeight = -height;
    bi.bmiHeader.biPlanes = 1;
    bi.bmiHeader.biBitCount = 32;
    bi.bmiHeader.biCompression = BI_RGB;

    void* bits = nullptr;
    HBITMAP dib = CreateDIBSection(memDC, &bi, DIB_RGB_COLORS, &bits, nullptr, 0);
    if (bits != nullptr) {
      const int srcStride = ((width * bmi->biBitCount + 31) / 32) * 4;
      const auto* src = reinterpret_cast<const uint8_t*>(bmi) + bmi->biSize +
                        bmi->biClrUsed * sizeof(RGBQUAD);
      auto* dst = static_cast<uint8_t*>(bits);
      for (int y = 0; y < height; ++y) {
        memcpy(dst + y * width * 4, src + y * srcStride, width * 4);
      }
      Gdiplus::Bitmap gdiBitmap(dib, nullptr);
      IStream* stream = nullptr;
      CreateStreamOnHGlobal(nullptr, TRUE, &stream);
      CLSID pngClsid;
      if (stream != nullptr &&
          Gdiplus::GetEncoderClsid(L"image/png", &pngClsid) >= 0) {
        gdiBitmap.Save(stream, &pngClsid, nullptr);
        STATSTG stat{};
        stream->Stat(&stat, STATFLAG_NONAME);
        const ULONG size = stat.cbSize.LowPart;
        std::vector<uint8_t> bytes(size);
        LARGE_INTEGER li{};
        stream->Seek(li, STREAM_SEEK_SET, nullptr);
        ULONG read = 0;
        stream->Read(bytes.data(), size, &read);
        stream->Release();

        EncodableMap map;
        map[EncodableValue("kind")] = EncodableValue("image");
        map[EncodableValue("bytes")] = EncodableValue(bytes);
        map[EncodableValue("extension")] = EncodableValue(".png");
        GlobalUnlock(handle);
        CloseClipboard();
        DeleteObject(dib);
        DeleteObject(hBitmap);
        DeleteDC(memDC);
        ReleaseDC(nullptr, hdc);
        Gdiplus::GdiplusShutdown(gdiplusToken);
        result->Success(EncodableValue(map));
        return;
      }
      if (stream != nullptr) stream->Release();
      DeleteObject(dib);
    }

    DeleteObject(hBitmap);
    DeleteDC(memDC);
    ReleaseDC(nullptr, hdc);
    GlobalUnlock(handle);
    CloseClipboard();
    Gdiplus::GdiplusShutdown(gdiplusToken);
    result->Success(EncodableMap{{EncodableValue("kind"), EncodableValue("empty")}});
  }
};

}  // namespace

void RegisterIrisExportPlugin(FlutterEngine* engine) {
  IrisExportPlugin::Register(engine);
}
