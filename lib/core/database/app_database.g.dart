// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ProjectGroupsTable extends ProjectGroups
    with TableInfo<$ProjectGroupsTable, ProjectGroup> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectGroupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, sortOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'project_groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProjectGroup> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProjectGroup map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProjectGroup(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $ProjectGroupsTable createAlias(String alias) {
    return $ProjectGroupsTable(attachedDatabase, alias);
  }
}

class ProjectGroup extends DataClass implements Insertable<ProjectGroup> {
  final int id;
  final String name;
  final int sortOrder;
  const ProjectGroup({
    required this.id,
    required this.name,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  ProjectGroupsCompanion toCompanion(bool nullToAbsent) {
    return ProjectGroupsCompanion(
      id: Value(id),
      name: Value(name),
      sortOrder: Value(sortOrder),
    );
  }

  factory ProjectGroup.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProjectGroup(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  ProjectGroup copyWith({int? id, String? name, int? sortOrder}) =>
      ProjectGroup(
        id: id ?? this.id,
        name: name ?? this.name,
        sortOrder: sortOrder ?? this.sortOrder,
      );
  ProjectGroup copyWithCompanion(ProjectGroupsCompanion data) {
    return ProjectGroup(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProjectGroup(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectGroup &&
          other.id == this.id &&
          other.name == this.name &&
          other.sortOrder == this.sortOrder);
}

class ProjectGroupsCompanion extends UpdateCompanion<ProjectGroup> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> sortOrder;
  const ProjectGroupsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  ProjectGroupsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.sortOrder = const Value.absent(),
  }) : name = Value(name);
  static Insertable<ProjectGroup> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  ProjectGroupsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? sortOrder,
  }) {
    return ProjectGroupsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectGroupsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }
}

class $ProjectsTable extends Projects with TableInfo<$ProjectsTable, Project> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<int> groupId = GeneratedColumn<int>(
    'group_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES project_groups (id)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _directorMeta = const VerificationMeta(
    'director',
  );
  @override
  late final GeneratedColumn<String> director = GeneratedColumn<String>(
    'director',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _clientNameMeta = const VerificationMeta(
    'clientName',
  );
  @override
  late final GeneratedColumn<String> clientName = GeneratedColumn<String>(
    'client_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('preproduction'),
  );
  static const VerificationMeta _iconCodeMeta = const VerificationMeta(
    'iconCode',
  );
  @override
  late final GeneratedColumn<int> iconCode = GeneratedColumn<int>(
    'icon_code',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0xe3f4),
  );
  static const VerificationMeta _coverImagePathMeta = const VerificationMeta(
    'coverImagePath',
  );
  @override
  late final GeneratedColumn<String> coverImagePath = GeneratedColumn<String>(
    'cover_image_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _shootingStartDateMeta = const VerificationMeta(
    'shootingStartDate',
  );
  @override
  late final GeneratedColumn<String> shootingStartDate =
      GeneratedColumn<String>(
        'shooting_start_date',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _shootingEndDateMeta = const VerificationMeta(
    'shootingEndDate',
  );
  @override
  late final GeneratedColumn<String> shootingEndDate = GeneratedColumn<String>(
    'shooting_end_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _googleEmailMeta = const VerificationMeta(
    'googleEmail',
  );
  @override
  late final GeneratedColumn<String> googleEmail = GeneratedColumn<String>(
    'google_email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scriptFilePathMeta = const VerificationMeta(
    'scriptFilePath',
  );
  @override
  late final GeneratedColumn<String> scriptFilePath = GeneratedColumn<String>(
    'script_file_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scriptFileNameMeta = const VerificationMeta(
    'scriptFileName',
  );
  @override
  late final GeneratedColumn<String> scriptFileName = GeneratedColumn<String>(
    'script_file_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    groupId,
    name,
    director,
    description,
    clientName,
    status,
    iconCode,
    coverImagePath,
    shootingStartDate,
    shootingEndDate,
    googleEmail,
    scriptFilePath,
    scriptFileName,
    sortOrder,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'projects';
  @override
  VerificationContext validateIntegrity(
    Insertable<Project> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('director')) {
      context.handle(
        _directorMeta,
        director.isAcceptableOrUnknown(data['director']!, _directorMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('client_name')) {
      context.handle(
        _clientNameMeta,
        clientName.isAcceptableOrUnknown(data['client_name']!, _clientNameMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('icon_code')) {
      context.handle(
        _iconCodeMeta,
        iconCode.isAcceptableOrUnknown(data['icon_code']!, _iconCodeMeta),
      );
    }
    if (data.containsKey('cover_image_path')) {
      context.handle(
        _coverImagePathMeta,
        coverImagePath.isAcceptableOrUnknown(
          data['cover_image_path']!,
          _coverImagePathMeta,
        ),
      );
    }
    if (data.containsKey('shooting_start_date')) {
      context.handle(
        _shootingStartDateMeta,
        shootingStartDate.isAcceptableOrUnknown(
          data['shooting_start_date']!,
          _shootingStartDateMeta,
        ),
      );
    }
    if (data.containsKey('shooting_end_date')) {
      context.handle(
        _shootingEndDateMeta,
        shootingEndDate.isAcceptableOrUnknown(
          data['shooting_end_date']!,
          _shootingEndDateMeta,
        ),
      );
    }
    if (data.containsKey('google_email')) {
      context.handle(
        _googleEmailMeta,
        googleEmail.isAcceptableOrUnknown(
          data['google_email']!,
          _googleEmailMeta,
        ),
      );
    }
    if (data.containsKey('script_file_path')) {
      context.handle(
        _scriptFilePathMeta,
        scriptFilePath.isAcceptableOrUnknown(
          data['script_file_path']!,
          _scriptFilePathMeta,
        ),
      );
    }
    if (data.containsKey('script_file_name')) {
      context.handle(
        _scriptFileNameMeta,
        scriptFileName.isAcceptableOrUnknown(
          data['script_file_name']!,
          _scriptFileNameMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Project map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Project(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}group_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      director: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}director'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      clientName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_name'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      iconCode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}icon_code'],
      )!,
      coverImagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_image_path'],
      ),
      shootingStartDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shooting_start_date'],
      ),
      shootingEndDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shooting_end_date'],
      ),
      googleEmail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}google_email'],
      ),
      scriptFilePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}script_file_path'],
      ),
      scriptFileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}script_file_name'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ProjectsTable createAlias(String alias) {
    return $ProjectsTable(attachedDatabase, alias);
  }
}

class Project extends DataClass implements Insertable<Project> {
  final int id;
  final int? groupId;
  final String name;
  final String? director;
  final String? description;
  final String? clientName;
  final String status;
  final int iconCode;
  final String? coverImagePath;
  final String? shootingStartDate;
  final String? shootingEndDate;
  final String? googleEmail;
  final String? scriptFilePath;
  final String? scriptFileName;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Project({
    required this.id,
    this.groupId,
    required this.name,
    this.director,
    this.description,
    this.clientName,
    required this.status,
    required this.iconCode,
    this.coverImagePath,
    this.shootingStartDate,
    this.shootingEndDate,
    this.googleEmail,
    this.scriptFilePath,
    this.scriptFileName,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || groupId != null) {
      map['group_id'] = Variable<int>(groupId);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || director != null) {
      map['director'] = Variable<String>(director);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || clientName != null) {
      map['client_name'] = Variable<String>(clientName);
    }
    map['status'] = Variable<String>(status);
    map['icon_code'] = Variable<int>(iconCode);
    if (!nullToAbsent || coverImagePath != null) {
      map['cover_image_path'] = Variable<String>(coverImagePath);
    }
    if (!nullToAbsent || shootingStartDate != null) {
      map['shooting_start_date'] = Variable<String>(shootingStartDate);
    }
    if (!nullToAbsent || shootingEndDate != null) {
      map['shooting_end_date'] = Variable<String>(shootingEndDate);
    }
    if (!nullToAbsent || googleEmail != null) {
      map['google_email'] = Variable<String>(googleEmail);
    }
    if (!nullToAbsent || scriptFilePath != null) {
      map['script_file_path'] = Variable<String>(scriptFilePath);
    }
    if (!nullToAbsent || scriptFileName != null) {
      map['script_file_name'] = Variable<String>(scriptFileName);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ProjectsCompanion toCompanion(bool nullToAbsent) {
    return ProjectsCompanion(
      id: Value(id),
      groupId: groupId == null && nullToAbsent
          ? const Value.absent()
          : Value(groupId),
      name: Value(name),
      director: director == null && nullToAbsent
          ? const Value.absent()
          : Value(director),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      clientName: clientName == null && nullToAbsent
          ? const Value.absent()
          : Value(clientName),
      status: Value(status),
      iconCode: Value(iconCode),
      coverImagePath: coverImagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(coverImagePath),
      shootingStartDate: shootingStartDate == null && nullToAbsent
          ? const Value.absent()
          : Value(shootingStartDate),
      shootingEndDate: shootingEndDate == null && nullToAbsent
          ? const Value.absent()
          : Value(shootingEndDate),
      googleEmail: googleEmail == null && nullToAbsent
          ? const Value.absent()
          : Value(googleEmail),
      scriptFilePath: scriptFilePath == null && nullToAbsent
          ? const Value.absent()
          : Value(scriptFilePath),
      scriptFileName: scriptFileName == null && nullToAbsent
          ? const Value.absent()
          : Value(scriptFileName),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Project.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Project(
      id: serializer.fromJson<int>(json['id']),
      groupId: serializer.fromJson<int?>(json['groupId']),
      name: serializer.fromJson<String>(json['name']),
      director: serializer.fromJson<String?>(json['director']),
      description: serializer.fromJson<String?>(json['description']),
      clientName: serializer.fromJson<String?>(json['clientName']),
      status: serializer.fromJson<String>(json['status']),
      iconCode: serializer.fromJson<int>(json['iconCode']),
      coverImagePath: serializer.fromJson<String?>(json['coverImagePath']),
      shootingStartDate: serializer.fromJson<String?>(
        json['shootingStartDate'],
      ),
      shootingEndDate: serializer.fromJson<String?>(json['shootingEndDate']),
      googleEmail: serializer.fromJson<String?>(json['googleEmail']),
      scriptFilePath: serializer.fromJson<String?>(json['scriptFilePath']),
      scriptFileName: serializer.fromJson<String?>(json['scriptFileName']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'groupId': serializer.toJson<int?>(groupId),
      'name': serializer.toJson<String>(name),
      'director': serializer.toJson<String?>(director),
      'description': serializer.toJson<String?>(description),
      'clientName': serializer.toJson<String?>(clientName),
      'status': serializer.toJson<String>(status),
      'iconCode': serializer.toJson<int>(iconCode),
      'coverImagePath': serializer.toJson<String?>(coverImagePath),
      'shootingStartDate': serializer.toJson<String?>(shootingStartDate),
      'shootingEndDate': serializer.toJson<String?>(shootingEndDate),
      'googleEmail': serializer.toJson<String?>(googleEmail),
      'scriptFilePath': serializer.toJson<String?>(scriptFilePath),
      'scriptFileName': serializer.toJson<String?>(scriptFileName),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Project copyWith({
    int? id,
    Value<int?> groupId = const Value.absent(),
    String? name,
    Value<String?> director = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<String?> clientName = const Value.absent(),
    String? status,
    int? iconCode,
    Value<String?> coverImagePath = const Value.absent(),
    Value<String?> shootingStartDate = const Value.absent(),
    Value<String?> shootingEndDate = const Value.absent(),
    Value<String?> googleEmail = const Value.absent(),
    Value<String?> scriptFilePath = const Value.absent(),
    Value<String?> scriptFileName = const Value.absent(),
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Project(
    id: id ?? this.id,
    groupId: groupId.present ? groupId.value : this.groupId,
    name: name ?? this.name,
    director: director.present ? director.value : this.director,
    description: description.present ? description.value : this.description,
    clientName: clientName.present ? clientName.value : this.clientName,
    status: status ?? this.status,
    iconCode: iconCode ?? this.iconCode,
    coverImagePath: coverImagePath.present
        ? coverImagePath.value
        : this.coverImagePath,
    shootingStartDate: shootingStartDate.present
        ? shootingStartDate.value
        : this.shootingStartDate,
    shootingEndDate: shootingEndDate.present
        ? shootingEndDate.value
        : this.shootingEndDate,
    googleEmail: googleEmail.present ? googleEmail.value : this.googleEmail,
    scriptFilePath: scriptFilePath.present
        ? scriptFilePath.value
        : this.scriptFilePath,
    scriptFileName: scriptFileName.present
        ? scriptFileName.value
        : this.scriptFileName,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Project copyWithCompanion(ProjectsCompanion data) {
    return Project(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      name: data.name.present ? data.name.value : this.name,
      director: data.director.present ? data.director.value : this.director,
      description: data.description.present
          ? data.description.value
          : this.description,
      clientName: data.clientName.present
          ? data.clientName.value
          : this.clientName,
      status: data.status.present ? data.status.value : this.status,
      iconCode: data.iconCode.present ? data.iconCode.value : this.iconCode,
      coverImagePath: data.coverImagePath.present
          ? data.coverImagePath.value
          : this.coverImagePath,
      shootingStartDate: data.shootingStartDate.present
          ? data.shootingStartDate.value
          : this.shootingStartDate,
      shootingEndDate: data.shootingEndDate.present
          ? data.shootingEndDate.value
          : this.shootingEndDate,
      googleEmail: data.googleEmail.present
          ? data.googleEmail.value
          : this.googleEmail,
      scriptFilePath: data.scriptFilePath.present
          ? data.scriptFilePath.value
          : this.scriptFilePath,
      scriptFileName: data.scriptFileName.present
          ? data.scriptFileName.value
          : this.scriptFileName,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Project(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('name: $name, ')
          ..write('director: $director, ')
          ..write('description: $description, ')
          ..write('clientName: $clientName, ')
          ..write('status: $status, ')
          ..write('iconCode: $iconCode, ')
          ..write('coverImagePath: $coverImagePath, ')
          ..write('shootingStartDate: $shootingStartDate, ')
          ..write('shootingEndDate: $shootingEndDate, ')
          ..write('googleEmail: $googleEmail, ')
          ..write('scriptFilePath: $scriptFilePath, ')
          ..write('scriptFileName: $scriptFileName, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    groupId,
    name,
    director,
    description,
    clientName,
    status,
    iconCode,
    coverImagePath,
    shootingStartDate,
    shootingEndDate,
    googleEmail,
    scriptFilePath,
    scriptFileName,
    sortOrder,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Project &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.name == this.name &&
          other.director == this.director &&
          other.description == this.description &&
          other.clientName == this.clientName &&
          other.status == this.status &&
          other.iconCode == this.iconCode &&
          other.coverImagePath == this.coverImagePath &&
          other.shootingStartDate == this.shootingStartDate &&
          other.shootingEndDate == this.shootingEndDate &&
          other.googleEmail == this.googleEmail &&
          other.scriptFilePath == this.scriptFilePath &&
          other.scriptFileName == this.scriptFileName &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ProjectsCompanion extends UpdateCompanion<Project> {
  final Value<int> id;
  final Value<int?> groupId;
  final Value<String> name;
  final Value<String?> director;
  final Value<String?> description;
  final Value<String?> clientName;
  final Value<String> status;
  final Value<int> iconCode;
  final Value<String?> coverImagePath;
  final Value<String?> shootingStartDate;
  final Value<String?> shootingEndDate;
  final Value<String?> googleEmail;
  final Value<String?> scriptFilePath;
  final Value<String?> scriptFileName;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const ProjectsCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.name = const Value.absent(),
    this.director = const Value.absent(),
    this.description = const Value.absent(),
    this.clientName = const Value.absent(),
    this.status = const Value.absent(),
    this.iconCode = const Value.absent(),
    this.coverImagePath = const Value.absent(),
    this.shootingStartDate = const Value.absent(),
    this.shootingEndDate = const Value.absent(),
    this.googleEmail = const Value.absent(),
    this.scriptFilePath = const Value.absent(),
    this.scriptFileName = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ProjectsCompanion.insert({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    required String name,
    this.director = const Value.absent(),
    this.description = const Value.absent(),
    this.clientName = const Value.absent(),
    this.status = const Value.absent(),
    this.iconCode = const Value.absent(),
    this.coverImagePath = const Value.absent(),
    this.shootingStartDate = const Value.absent(),
    this.shootingEndDate = const Value.absent(),
    this.googleEmail = const Value.absent(),
    this.scriptFilePath = const Value.absent(),
    this.scriptFileName = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Project> custom({
    Expression<int>? id,
    Expression<int>? groupId,
    Expression<String>? name,
    Expression<String>? director,
    Expression<String>? description,
    Expression<String>? clientName,
    Expression<String>? status,
    Expression<int>? iconCode,
    Expression<String>? coverImagePath,
    Expression<String>? shootingStartDate,
    Expression<String>? shootingEndDate,
    Expression<String>? googleEmail,
    Expression<String>? scriptFilePath,
    Expression<String>? scriptFileName,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (name != null) 'name': name,
      if (director != null) 'director': director,
      if (description != null) 'description': description,
      if (clientName != null) 'client_name': clientName,
      if (status != null) 'status': status,
      if (iconCode != null) 'icon_code': iconCode,
      if (coverImagePath != null) 'cover_image_path': coverImagePath,
      if (shootingStartDate != null) 'shooting_start_date': shootingStartDate,
      if (shootingEndDate != null) 'shooting_end_date': shootingEndDate,
      if (googleEmail != null) 'google_email': googleEmail,
      if (scriptFilePath != null) 'script_file_path': scriptFilePath,
      if (scriptFileName != null) 'script_file_name': scriptFileName,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ProjectsCompanion copyWith({
    Value<int>? id,
    Value<int?>? groupId,
    Value<String>? name,
    Value<String?>? director,
    Value<String?>? description,
    Value<String?>? clientName,
    Value<String>? status,
    Value<int>? iconCode,
    Value<String?>? coverImagePath,
    Value<String?>? shootingStartDate,
    Value<String?>? shootingEndDate,
    Value<String?>? googleEmail,
    Value<String?>? scriptFilePath,
    Value<String?>? scriptFileName,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return ProjectsCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      director: director ?? this.director,
      description: description ?? this.description,
      clientName: clientName ?? this.clientName,
      status: status ?? this.status,
      iconCode: iconCode ?? this.iconCode,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      shootingStartDate: shootingStartDate ?? this.shootingStartDate,
      shootingEndDate: shootingEndDate ?? this.shootingEndDate,
      googleEmail: googleEmail ?? this.googleEmail,
      scriptFilePath: scriptFilePath ?? this.scriptFilePath,
      scriptFileName: scriptFileName ?? this.scriptFileName,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<int>(groupId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (director.present) {
      map['director'] = Variable<String>(director.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (clientName.present) {
      map['client_name'] = Variable<String>(clientName.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (iconCode.present) {
      map['icon_code'] = Variable<int>(iconCode.value);
    }
    if (coverImagePath.present) {
      map['cover_image_path'] = Variable<String>(coverImagePath.value);
    }
    if (shootingStartDate.present) {
      map['shooting_start_date'] = Variable<String>(shootingStartDate.value);
    }
    if (shootingEndDate.present) {
      map['shooting_end_date'] = Variable<String>(shootingEndDate.value);
    }
    if (googleEmail.present) {
      map['google_email'] = Variable<String>(googleEmail.value);
    }
    if (scriptFilePath.present) {
      map['script_file_path'] = Variable<String>(scriptFilePath.value);
    }
    if (scriptFileName.present) {
      map['script_file_name'] = Variable<String>(scriptFileName.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectsCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('name: $name, ')
          ..write('director: $director, ')
          ..write('description: $description, ')
          ..write('clientName: $clientName, ')
          ..write('status: $status, ')
          ..write('iconCode: $iconCode, ')
          ..write('coverImagePath: $coverImagePath, ')
          ..write('shootingStartDate: $shootingStartDate, ')
          ..write('shootingEndDate: $shootingEndDate, ')
          ..write('googleEmail: $googleEmail, ')
          ..write('scriptFilePath: $scriptFilePath, ')
          ..write('scriptFileName: $scriptFileName, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $LocationSitesTable extends LocationSites
    with TableInfo<$LocationSitesTable, LocationSite> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocationSitesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<int> projectId = GeneratedColumn<int>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _floorPlanJsonMeta = const VerificationMeta(
    'floorPlanJson',
  );
  @override
  late final GeneratedColumn<String> floorPlanJson = GeneratedColumn<String>(
    'floor_plan_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scanPathMeta = const VerificationMeta(
    'scanPath',
  );
  @override
  late final GeneratedColumn<String> scanPath = GeneratedColumn<String>(
    'scan_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scanSourceMeta = const VerificationMeta(
    'scanSource',
  );
  @override
  late final GeneratedColumn<String> scanSource = GeneratedColumn<String>(
    'scan_source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scanMetadataJsonMeta = const VerificationMeta(
    'scanMetadataJson',
  );
  @override
  late final GeneratedColumn<String> scanMetadataJson = GeneratedColumn<String>(
    'scan_metadata_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    name,
    description,
    notes,
    floorPlanJson,
    scanPath,
    scanSource,
    scanMetadataJson,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'location_sites';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocationSite> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('floor_plan_json')) {
      context.handle(
        _floorPlanJsonMeta,
        floorPlanJson.isAcceptableOrUnknown(
          data['floor_plan_json']!,
          _floorPlanJsonMeta,
        ),
      );
    }
    if (data.containsKey('scan_path')) {
      context.handle(
        _scanPathMeta,
        scanPath.isAcceptableOrUnknown(data['scan_path']!, _scanPathMeta),
      );
    }
    if (data.containsKey('scan_source')) {
      context.handle(
        _scanSourceMeta,
        scanSource.isAcceptableOrUnknown(data['scan_source']!, _scanSourceMeta),
      );
    }
    if (data.containsKey('scan_metadata_json')) {
      context.handle(
        _scanMetadataJsonMeta,
        scanMetadataJson.isAcceptableOrUnknown(
          data['scan_metadata_json']!,
          _scanMetadataJsonMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocationSite map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocationSite(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}project_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      floorPlanJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}floor_plan_json'],
      ),
      scanPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scan_path'],
      ),
      scanSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scan_source'],
      ),
      scanMetadataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scan_metadata_json'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $LocationSitesTable createAlias(String alias) {
    return $LocationSitesTable(attachedDatabase, alias);
  }
}

class LocationSite extends DataClass implements Insertable<LocationSite> {
  final int id;
  final int projectId;
  final String name;
  final String? description;
  final String? notes;
  final String? floorPlanJson;
  final String? scanPath;
  final String? scanSource;
  final String? scanMetadataJson;
  final int sortOrder;
  const LocationSite({
    required this.id,
    required this.projectId,
    required this.name,
    this.description,
    this.notes,
    this.floorPlanJson,
    this.scanPath,
    this.scanSource,
    this.scanMetadataJson,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['project_id'] = Variable<int>(projectId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || floorPlanJson != null) {
      map['floor_plan_json'] = Variable<String>(floorPlanJson);
    }
    if (!nullToAbsent || scanPath != null) {
      map['scan_path'] = Variable<String>(scanPath);
    }
    if (!nullToAbsent || scanSource != null) {
      map['scan_source'] = Variable<String>(scanSource);
    }
    if (!nullToAbsent || scanMetadataJson != null) {
      map['scan_metadata_json'] = Variable<String>(scanMetadataJson);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  LocationSitesCompanion toCompanion(bool nullToAbsent) {
    return LocationSitesCompanion(
      id: Value(id),
      projectId: Value(projectId),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      floorPlanJson: floorPlanJson == null && nullToAbsent
          ? const Value.absent()
          : Value(floorPlanJson),
      scanPath: scanPath == null && nullToAbsent
          ? const Value.absent()
          : Value(scanPath),
      scanSource: scanSource == null && nullToAbsent
          ? const Value.absent()
          : Value(scanSource),
      scanMetadataJson: scanMetadataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(scanMetadataJson),
      sortOrder: Value(sortOrder),
    );
  }

  factory LocationSite.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocationSite(
      id: serializer.fromJson<int>(json['id']),
      projectId: serializer.fromJson<int>(json['projectId']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      notes: serializer.fromJson<String?>(json['notes']),
      floorPlanJson: serializer.fromJson<String?>(json['floorPlanJson']),
      scanPath: serializer.fromJson<String?>(json['scanPath']),
      scanSource: serializer.fromJson<String?>(json['scanSource']),
      scanMetadataJson: serializer.fromJson<String?>(json['scanMetadataJson']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'projectId': serializer.toJson<int>(projectId),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'notes': serializer.toJson<String?>(notes),
      'floorPlanJson': serializer.toJson<String?>(floorPlanJson),
      'scanPath': serializer.toJson<String?>(scanPath),
      'scanSource': serializer.toJson<String?>(scanSource),
      'scanMetadataJson': serializer.toJson<String?>(scanMetadataJson),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  LocationSite copyWith({
    int? id,
    int? projectId,
    String? name,
    Value<String?> description = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<String?> floorPlanJson = const Value.absent(),
    Value<String?> scanPath = const Value.absent(),
    Value<String?> scanSource = const Value.absent(),
    Value<String?> scanMetadataJson = const Value.absent(),
    int? sortOrder,
  }) => LocationSite(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    notes: notes.present ? notes.value : this.notes,
    floorPlanJson: floorPlanJson.present
        ? floorPlanJson.value
        : this.floorPlanJson,
    scanPath: scanPath.present ? scanPath.value : this.scanPath,
    scanSource: scanSource.present ? scanSource.value : this.scanSource,
    scanMetadataJson: scanMetadataJson.present
        ? scanMetadataJson.value
        : this.scanMetadataJson,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  LocationSite copyWithCompanion(LocationSitesCompanion data) {
    return LocationSite(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      notes: data.notes.present ? data.notes.value : this.notes,
      floorPlanJson: data.floorPlanJson.present
          ? data.floorPlanJson.value
          : this.floorPlanJson,
      scanPath: data.scanPath.present ? data.scanPath.value : this.scanPath,
      scanSource: data.scanSource.present
          ? data.scanSource.value
          : this.scanSource,
      scanMetadataJson: data.scanMetadataJson.present
          ? data.scanMetadataJson.value
          : this.scanMetadataJson,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocationSite(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('notes: $notes, ')
          ..write('floorPlanJson: $floorPlanJson, ')
          ..write('scanPath: $scanPath, ')
          ..write('scanSource: $scanSource, ')
          ..write('scanMetadataJson: $scanMetadataJson, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    name,
    description,
    notes,
    floorPlanJson,
    scanPath,
    scanSource,
    scanMetadataJson,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocationSite &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.name == this.name &&
          other.description == this.description &&
          other.notes == this.notes &&
          other.floorPlanJson == this.floorPlanJson &&
          other.scanPath == this.scanPath &&
          other.scanSource == this.scanSource &&
          other.scanMetadataJson == this.scanMetadataJson &&
          other.sortOrder == this.sortOrder);
}

class LocationSitesCompanion extends UpdateCompanion<LocationSite> {
  final Value<int> id;
  final Value<int> projectId;
  final Value<String> name;
  final Value<String?> description;
  final Value<String?> notes;
  final Value<String?> floorPlanJson;
  final Value<String?> scanPath;
  final Value<String?> scanSource;
  final Value<String?> scanMetadataJson;
  final Value<int> sortOrder;
  const LocationSitesCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.notes = const Value.absent(),
    this.floorPlanJson = const Value.absent(),
    this.scanPath = const Value.absent(),
    this.scanSource = const Value.absent(),
    this.scanMetadataJson = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  LocationSitesCompanion.insert({
    this.id = const Value.absent(),
    required int projectId,
    required String name,
    this.description = const Value.absent(),
    this.notes = const Value.absent(),
    this.floorPlanJson = const Value.absent(),
    this.scanPath = const Value.absent(),
    this.scanSource = const Value.absent(),
    this.scanMetadataJson = const Value.absent(),
    this.sortOrder = const Value.absent(),
  }) : projectId = Value(projectId),
       name = Value(name);
  static Insertable<LocationSite> custom({
    Expression<int>? id,
    Expression<int>? projectId,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? notes,
    Expression<String>? floorPlanJson,
    Expression<String>? scanPath,
    Expression<String>? scanSource,
    Expression<String>? scanMetadataJson,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (notes != null) 'notes': notes,
      if (floorPlanJson != null) 'floor_plan_json': floorPlanJson,
      if (scanPath != null) 'scan_path': scanPath,
      if (scanSource != null) 'scan_source': scanSource,
      if (scanMetadataJson != null) 'scan_metadata_json': scanMetadataJson,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  LocationSitesCompanion copyWith({
    Value<int>? id,
    Value<int>? projectId,
    Value<String>? name,
    Value<String?>? description,
    Value<String?>? notes,
    Value<String?>? floorPlanJson,
    Value<String?>? scanPath,
    Value<String?>? scanSource,
    Value<String?>? scanMetadataJson,
    Value<int>? sortOrder,
  }) {
    return LocationSitesCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      floorPlanJson: floorPlanJson ?? this.floorPlanJson,
      scanPath: scanPath ?? this.scanPath,
      scanSource: scanSource ?? this.scanSource,
      scanMetadataJson: scanMetadataJson ?? this.scanMetadataJson,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<int>(projectId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (floorPlanJson.present) {
      map['floor_plan_json'] = Variable<String>(floorPlanJson.value);
    }
    if (scanPath.present) {
      map['scan_path'] = Variable<String>(scanPath.value);
    }
    if (scanSource.present) {
      map['scan_source'] = Variable<String>(scanSource.value);
    }
    if (scanMetadataJson.present) {
      map['scan_metadata_json'] = Variable<String>(scanMetadataJson.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocationSitesCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('notes: $notes, ')
          ..write('floorPlanJson: $floorPlanJson, ')
          ..write('scanPath: $scanPath, ')
          ..write('scanSource: $scanSource, ')
          ..write('scanMetadataJson: $scanMetadataJson, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }
}

class $LocationBasePlansTable extends LocationBasePlans
    with TableInfo<$LocationBasePlansTable, LocationBasePlan> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocationBasePlansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<int> projectId = GeneratedColumn<int>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id)',
    ),
  );
  static const VerificationMeta _siteIdMeta = const VerificationMeta('siteId');
  @override
  late final GeneratedColumn<int> siteId = GeneratedColumn<int>(
    'site_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES location_sites (id)',
    ),
  );
  static const VerificationMeta _locationNameMeta = const VerificationMeta(
    'locationName',
  );
  @override
  late final GeneratedColumn<String> locationName = GeneratedColumn<String>(
    'location_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imagePathMeta = const VerificationMeta(
    'imagePath',
  );
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
    'image_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('#94A3B8'),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _model3dPathMeta = const VerificationMeta(
    'model3dPath',
  );
  @override
  late final GeneratedColumn<String> model3dPath = GeneratedColumn<String>(
    'model3d_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _floorPlanJsonMeta = const VerificationMeta(
    'floorPlanJson',
  );
  @override
  late final GeneratedColumn<String> floorPlanJson = GeneratedColumn<String>(
    'floor_plan_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scanPathMeta = const VerificationMeta(
    'scanPath',
  );
  @override
  late final GeneratedColumn<String> scanPath = GeneratedColumn<String>(
    'scan_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scanSourceMeta = const VerificationMeta(
    'scanSource',
  );
  @override
  late final GeneratedColumn<String> scanSource = GeneratedColumn<String>(
    'scan_source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scanMetadataJsonMeta = const VerificationMeta(
    'scanMetadataJson',
  );
  @override
  late final GeneratedColumn<String> scanMetadataJson = GeneratedColumn<String>(
    'scan_metadata_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    siteId,
    locationName,
    description,
    imagePath,
    color,
    notes,
    model3dPath,
    floorPlanJson,
    scanPath,
    scanSource,
    scanMetadataJson,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'location_base_plans';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocationBasePlan> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('site_id')) {
      context.handle(
        _siteIdMeta,
        siteId.isAcceptableOrUnknown(data['site_id']!, _siteIdMeta),
      );
    }
    if (data.containsKey('location_name')) {
      context.handle(
        _locationNameMeta,
        locationName.isAcceptableOrUnknown(
          data['location_name']!,
          _locationNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_locationNameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('image_path')) {
      context.handle(
        _imagePathMeta,
        imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('model3d_path')) {
      context.handle(
        _model3dPathMeta,
        model3dPath.isAcceptableOrUnknown(
          data['model3d_path']!,
          _model3dPathMeta,
        ),
      );
    }
    if (data.containsKey('floor_plan_json')) {
      context.handle(
        _floorPlanJsonMeta,
        floorPlanJson.isAcceptableOrUnknown(
          data['floor_plan_json']!,
          _floorPlanJsonMeta,
        ),
      );
    }
    if (data.containsKey('scan_path')) {
      context.handle(
        _scanPathMeta,
        scanPath.isAcceptableOrUnknown(data['scan_path']!, _scanPathMeta),
      );
    }
    if (data.containsKey('scan_source')) {
      context.handle(
        _scanSourceMeta,
        scanSource.isAcceptableOrUnknown(data['scan_source']!, _scanSourceMeta),
      );
    }
    if (data.containsKey('scan_metadata_json')) {
      context.handle(
        _scanMetadataJsonMeta,
        scanMetadataJson.isAcceptableOrUnknown(
          data['scan_metadata_json']!,
          _scanMetadataJsonMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocationBasePlan map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocationBasePlan(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}project_id'],
      )!,
      siteId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}site_id'],
      ),
      locationName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location_name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      imagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_path'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      model3dPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model3d_path'],
      ),
      floorPlanJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}floor_plan_json'],
      ),
      scanPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scan_path'],
      ),
      scanSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scan_source'],
      ),
      scanMetadataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scan_metadata_json'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $LocationBasePlansTable createAlias(String alias) {
    return $LocationBasePlansTable(attachedDatabase, alias);
  }
}

class LocationBasePlan extends DataClass
    implements Insertable<LocationBasePlan> {
  final int id;
  final int projectId;
  final int? siteId;
  final String locationName;
  final String? description;
  final String? imagePath;
  final String color;
  final String? notes;
  final String? model3dPath;
  final String? floorPlanJson;
  final String? scanPath;
  final String? scanSource;
  final String? scanMetadataJson;
  final int sortOrder;
  const LocationBasePlan({
    required this.id,
    required this.projectId,
    this.siteId,
    required this.locationName,
    this.description,
    this.imagePath,
    required this.color,
    this.notes,
    this.model3dPath,
    this.floorPlanJson,
    this.scanPath,
    this.scanSource,
    this.scanMetadataJson,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['project_id'] = Variable<int>(projectId);
    if (!nullToAbsent || siteId != null) {
      map['site_id'] = Variable<int>(siteId);
    }
    map['location_name'] = Variable<String>(locationName);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || imagePath != null) {
      map['image_path'] = Variable<String>(imagePath);
    }
    map['color'] = Variable<String>(color);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || model3dPath != null) {
      map['model3d_path'] = Variable<String>(model3dPath);
    }
    if (!nullToAbsent || floorPlanJson != null) {
      map['floor_plan_json'] = Variable<String>(floorPlanJson);
    }
    if (!nullToAbsent || scanPath != null) {
      map['scan_path'] = Variable<String>(scanPath);
    }
    if (!nullToAbsent || scanSource != null) {
      map['scan_source'] = Variable<String>(scanSource);
    }
    if (!nullToAbsent || scanMetadataJson != null) {
      map['scan_metadata_json'] = Variable<String>(scanMetadataJson);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  LocationBasePlansCompanion toCompanion(bool nullToAbsent) {
    return LocationBasePlansCompanion(
      id: Value(id),
      projectId: Value(projectId),
      siteId: siteId == null && nullToAbsent
          ? const Value.absent()
          : Value(siteId),
      locationName: Value(locationName),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      imagePath: imagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(imagePath),
      color: Value(color),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      model3dPath: model3dPath == null && nullToAbsent
          ? const Value.absent()
          : Value(model3dPath),
      floorPlanJson: floorPlanJson == null && nullToAbsent
          ? const Value.absent()
          : Value(floorPlanJson),
      scanPath: scanPath == null && nullToAbsent
          ? const Value.absent()
          : Value(scanPath),
      scanSource: scanSource == null && nullToAbsent
          ? const Value.absent()
          : Value(scanSource),
      scanMetadataJson: scanMetadataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(scanMetadataJson),
      sortOrder: Value(sortOrder),
    );
  }

  factory LocationBasePlan.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocationBasePlan(
      id: serializer.fromJson<int>(json['id']),
      projectId: serializer.fromJson<int>(json['projectId']),
      siteId: serializer.fromJson<int?>(json['siteId']),
      locationName: serializer.fromJson<String>(json['locationName']),
      description: serializer.fromJson<String?>(json['description']),
      imagePath: serializer.fromJson<String?>(json['imagePath']),
      color: serializer.fromJson<String>(json['color']),
      notes: serializer.fromJson<String?>(json['notes']),
      model3dPath: serializer.fromJson<String?>(json['model3dPath']),
      floorPlanJson: serializer.fromJson<String?>(json['floorPlanJson']),
      scanPath: serializer.fromJson<String?>(json['scanPath']),
      scanSource: serializer.fromJson<String?>(json['scanSource']),
      scanMetadataJson: serializer.fromJson<String?>(json['scanMetadataJson']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'projectId': serializer.toJson<int>(projectId),
      'siteId': serializer.toJson<int?>(siteId),
      'locationName': serializer.toJson<String>(locationName),
      'description': serializer.toJson<String?>(description),
      'imagePath': serializer.toJson<String?>(imagePath),
      'color': serializer.toJson<String>(color),
      'notes': serializer.toJson<String?>(notes),
      'model3dPath': serializer.toJson<String?>(model3dPath),
      'floorPlanJson': serializer.toJson<String?>(floorPlanJson),
      'scanPath': serializer.toJson<String?>(scanPath),
      'scanSource': serializer.toJson<String?>(scanSource),
      'scanMetadataJson': serializer.toJson<String?>(scanMetadataJson),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  LocationBasePlan copyWith({
    int? id,
    int? projectId,
    Value<int?> siteId = const Value.absent(),
    String? locationName,
    Value<String?> description = const Value.absent(),
    Value<String?> imagePath = const Value.absent(),
    String? color,
    Value<String?> notes = const Value.absent(),
    Value<String?> model3dPath = const Value.absent(),
    Value<String?> floorPlanJson = const Value.absent(),
    Value<String?> scanPath = const Value.absent(),
    Value<String?> scanSource = const Value.absent(),
    Value<String?> scanMetadataJson = const Value.absent(),
    int? sortOrder,
  }) => LocationBasePlan(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    siteId: siteId.present ? siteId.value : this.siteId,
    locationName: locationName ?? this.locationName,
    description: description.present ? description.value : this.description,
    imagePath: imagePath.present ? imagePath.value : this.imagePath,
    color: color ?? this.color,
    notes: notes.present ? notes.value : this.notes,
    model3dPath: model3dPath.present ? model3dPath.value : this.model3dPath,
    floorPlanJson: floorPlanJson.present
        ? floorPlanJson.value
        : this.floorPlanJson,
    scanPath: scanPath.present ? scanPath.value : this.scanPath,
    scanSource: scanSource.present ? scanSource.value : this.scanSource,
    scanMetadataJson: scanMetadataJson.present
        ? scanMetadataJson.value
        : this.scanMetadataJson,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  LocationBasePlan copyWithCompanion(LocationBasePlansCompanion data) {
    return LocationBasePlan(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      siteId: data.siteId.present ? data.siteId.value : this.siteId,
      locationName: data.locationName.present
          ? data.locationName.value
          : this.locationName,
      description: data.description.present
          ? data.description.value
          : this.description,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      color: data.color.present ? data.color.value : this.color,
      notes: data.notes.present ? data.notes.value : this.notes,
      model3dPath: data.model3dPath.present
          ? data.model3dPath.value
          : this.model3dPath,
      floorPlanJson: data.floorPlanJson.present
          ? data.floorPlanJson.value
          : this.floorPlanJson,
      scanPath: data.scanPath.present ? data.scanPath.value : this.scanPath,
      scanSource: data.scanSource.present
          ? data.scanSource.value
          : this.scanSource,
      scanMetadataJson: data.scanMetadataJson.present
          ? data.scanMetadataJson.value
          : this.scanMetadataJson,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocationBasePlan(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('siteId: $siteId, ')
          ..write('locationName: $locationName, ')
          ..write('description: $description, ')
          ..write('imagePath: $imagePath, ')
          ..write('color: $color, ')
          ..write('notes: $notes, ')
          ..write('model3dPath: $model3dPath, ')
          ..write('floorPlanJson: $floorPlanJson, ')
          ..write('scanPath: $scanPath, ')
          ..write('scanSource: $scanSource, ')
          ..write('scanMetadataJson: $scanMetadataJson, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    siteId,
    locationName,
    description,
    imagePath,
    color,
    notes,
    model3dPath,
    floorPlanJson,
    scanPath,
    scanSource,
    scanMetadataJson,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocationBasePlan &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.siteId == this.siteId &&
          other.locationName == this.locationName &&
          other.description == this.description &&
          other.imagePath == this.imagePath &&
          other.color == this.color &&
          other.notes == this.notes &&
          other.model3dPath == this.model3dPath &&
          other.floorPlanJson == this.floorPlanJson &&
          other.scanPath == this.scanPath &&
          other.scanSource == this.scanSource &&
          other.scanMetadataJson == this.scanMetadataJson &&
          other.sortOrder == this.sortOrder);
}

class LocationBasePlansCompanion extends UpdateCompanion<LocationBasePlan> {
  final Value<int> id;
  final Value<int> projectId;
  final Value<int?> siteId;
  final Value<String> locationName;
  final Value<String?> description;
  final Value<String?> imagePath;
  final Value<String> color;
  final Value<String?> notes;
  final Value<String?> model3dPath;
  final Value<String?> floorPlanJson;
  final Value<String?> scanPath;
  final Value<String?> scanSource;
  final Value<String?> scanMetadataJson;
  final Value<int> sortOrder;
  const LocationBasePlansCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.siteId = const Value.absent(),
    this.locationName = const Value.absent(),
    this.description = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.color = const Value.absent(),
    this.notes = const Value.absent(),
    this.model3dPath = const Value.absent(),
    this.floorPlanJson = const Value.absent(),
    this.scanPath = const Value.absent(),
    this.scanSource = const Value.absent(),
    this.scanMetadataJson = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  LocationBasePlansCompanion.insert({
    this.id = const Value.absent(),
    required int projectId,
    this.siteId = const Value.absent(),
    required String locationName,
    this.description = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.color = const Value.absent(),
    this.notes = const Value.absent(),
    this.model3dPath = const Value.absent(),
    this.floorPlanJson = const Value.absent(),
    this.scanPath = const Value.absent(),
    this.scanSource = const Value.absent(),
    this.scanMetadataJson = const Value.absent(),
    this.sortOrder = const Value.absent(),
  }) : projectId = Value(projectId),
       locationName = Value(locationName);
  static Insertable<LocationBasePlan> custom({
    Expression<int>? id,
    Expression<int>? projectId,
    Expression<int>? siteId,
    Expression<String>? locationName,
    Expression<String>? description,
    Expression<String>? imagePath,
    Expression<String>? color,
    Expression<String>? notes,
    Expression<String>? model3dPath,
    Expression<String>? floorPlanJson,
    Expression<String>? scanPath,
    Expression<String>? scanSource,
    Expression<String>? scanMetadataJson,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (siteId != null) 'site_id': siteId,
      if (locationName != null) 'location_name': locationName,
      if (description != null) 'description': description,
      if (imagePath != null) 'image_path': imagePath,
      if (color != null) 'color': color,
      if (notes != null) 'notes': notes,
      if (model3dPath != null) 'model3d_path': model3dPath,
      if (floorPlanJson != null) 'floor_plan_json': floorPlanJson,
      if (scanPath != null) 'scan_path': scanPath,
      if (scanSource != null) 'scan_source': scanSource,
      if (scanMetadataJson != null) 'scan_metadata_json': scanMetadataJson,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  LocationBasePlansCompanion copyWith({
    Value<int>? id,
    Value<int>? projectId,
    Value<int?>? siteId,
    Value<String>? locationName,
    Value<String?>? description,
    Value<String?>? imagePath,
    Value<String>? color,
    Value<String?>? notes,
    Value<String?>? model3dPath,
    Value<String?>? floorPlanJson,
    Value<String?>? scanPath,
    Value<String?>? scanSource,
    Value<String?>? scanMetadataJson,
    Value<int>? sortOrder,
  }) {
    return LocationBasePlansCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      siteId: siteId ?? this.siteId,
      locationName: locationName ?? this.locationName,
      description: description ?? this.description,
      imagePath: imagePath ?? this.imagePath,
      color: color ?? this.color,
      notes: notes ?? this.notes,
      model3dPath: model3dPath ?? this.model3dPath,
      floorPlanJson: floorPlanJson ?? this.floorPlanJson,
      scanPath: scanPath ?? this.scanPath,
      scanSource: scanSource ?? this.scanSource,
      scanMetadataJson: scanMetadataJson ?? this.scanMetadataJson,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<int>(projectId.value);
    }
    if (siteId.present) {
      map['site_id'] = Variable<int>(siteId.value);
    }
    if (locationName.present) {
      map['location_name'] = Variable<String>(locationName.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (model3dPath.present) {
      map['model3d_path'] = Variable<String>(model3dPath.value);
    }
    if (floorPlanJson.present) {
      map['floor_plan_json'] = Variable<String>(floorPlanJson.value);
    }
    if (scanPath.present) {
      map['scan_path'] = Variable<String>(scanPath.value);
    }
    if (scanSource.present) {
      map['scan_source'] = Variable<String>(scanSource.value);
    }
    if (scanMetadataJson.present) {
      map['scan_metadata_json'] = Variable<String>(scanMetadataJson.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocationBasePlansCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('siteId: $siteId, ')
          ..write('locationName: $locationName, ')
          ..write('description: $description, ')
          ..write('imagePath: $imagePath, ')
          ..write('color: $color, ')
          ..write('notes: $notes, ')
          ..write('model3dPath: $model3dPath, ')
          ..write('floorPlanJson: $floorPlanJson, ')
          ..write('scanPath: $scanPath, ')
          ..write('scanSource: $scanSource, ')
          ..write('scanMetadataJson: $scanMetadataJson, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }
}

class $ScenesTable extends Scenes with TableInfo<$ScenesTable, Scene> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScenesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<int> projectId = GeneratedColumn<int>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id)',
    ),
  );
  static const VerificationMeta _numberMeta = const VerificationMeta('number');
  @override
  late final GeneratedColumn<int> number = GeneratedColumn<int>(
    'number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _locationCanonicalMeta = const VerificationMeta(
    'locationCanonical',
  );
  @override
  late final GeneratedColumn<String> locationCanonical =
      GeneratedColumn<String>(
        'location_canonical',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _locationPureNameMeta = const VerificationMeta(
    'locationPureName',
  );
  @override
  late final GeneratedColumn<String> locationPureName = GeneratedColumn<String>(
    'location_pure_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _locationSiteIdMeta = const VerificationMeta(
    'locationSiteId',
  );
  @override
  late final GeneratedColumn<int> locationSiteId = GeneratedColumn<int>(
    'location_site_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES location_sites (id)',
    ),
  );
  static const VerificationMeta _locationIdMeta = const VerificationMeta(
    'locationId',
  );
  @override
  late final GeneratedColumn<int> locationId = GeneratedColumn<int>(
    'location_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES location_base_plans (id)',
    ),
  );
  static const VerificationMeta _intExtMeta = const VerificationMeta('intExt');
  @override
  late final GeneratedColumn<String> intExt = GeneratedColumn<String>(
    'int_ext',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('EXT'),
  );
  static const VerificationMeta _dayNightMeta = const VerificationMeta(
    'dayNight',
  );
  @override
  late final GeneratedColumn<String> dayNight = GeneratedColumn<String>(
    'day_night',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('DÍA'),
  );
  static const VerificationMeta _locationColorMeta = const VerificationMeta(
    'locationColor',
  );
  @override
  late final GeneratedColumn<String> locationColor = GeneratedColumn<String>(
    'location_color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _actionTextMeta = const VerificationMeta(
    'actionText',
  );
  @override
  late final GeneratedColumn<String> actionText = GeneratedColumn<String>(
    'action_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceStartIndexMeta = const VerificationMeta(
    'sourceStartIndex',
  );
  @override
  late final GeneratedColumn<int> sourceStartIndex = GeneratedColumn<int>(
    'source_start_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMinutesMeta = const VerificationMeta(
    'durationMinutes',
  );
  @override
  late final GeneratedColumn<int> durationMinutes = GeneratedColumn<int>(
    'duration_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _autoNumberingMeta = const VerificationMeta(
    'autoNumbering',
  );
  @override
  late final GeneratedColumn<bool> autoNumbering = GeneratedColumn<bool>(
    'auto_numbering',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("auto_numbering" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    number,
    name,
    locationCanonical,
    locationPureName,
    locationSiteId,
    locationId,
    intExt,
    dayNight,
    locationColor,
    description,
    actionText,
    sourceStartIndex,
    durationMinutes,
    autoNumbering,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scenes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Scene> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('number')) {
      context.handle(
        _numberMeta,
        number.isAcceptableOrUnknown(data['number']!, _numberMeta),
      );
    } else if (isInserting) {
      context.missing(_numberMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('location_canonical')) {
      context.handle(
        _locationCanonicalMeta,
        locationCanonical.isAcceptableOrUnknown(
          data['location_canonical']!,
          _locationCanonicalMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_locationCanonicalMeta);
    }
    if (data.containsKey('location_pure_name')) {
      context.handle(
        _locationPureNameMeta,
        locationPureName.isAcceptableOrUnknown(
          data['location_pure_name']!,
          _locationPureNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_locationPureNameMeta);
    }
    if (data.containsKey('location_site_id')) {
      context.handle(
        _locationSiteIdMeta,
        locationSiteId.isAcceptableOrUnknown(
          data['location_site_id']!,
          _locationSiteIdMeta,
        ),
      );
    }
    if (data.containsKey('location_id')) {
      context.handle(
        _locationIdMeta,
        locationId.isAcceptableOrUnknown(data['location_id']!, _locationIdMeta),
      );
    }
    if (data.containsKey('int_ext')) {
      context.handle(
        _intExtMeta,
        intExt.isAcceptableOrUnknown(data['int_ext']!, _intExtMeta),
      );
    }
    if (data.containsKey('day_night')) {
      context.handle(
        _dayNightMeta,
        dayNight.isAcceptableOrUnknown(data['day_night']!, _dayNightMeta),
      );
    }
    if (data.containsKey('location_color')) {
      context.handle(
        _locationColorMeta,
        locationColor.isAcceptableOrUnknown(
          data['location_color']!,
          _locationColorMeta,
        ),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('action_text')) {
      context.handle(
        _actionTextMeta,
        actionText.isAcceptableOrUnknown(data['action_text']!, _actionTextMeta),
      );
    }
    if (data.containsKey('source_start_index')) {
      context.handle(
        _sourceStartIndexMeta,
        sourceStartIndex.isAcceptableOrUnknown(
          data['source_start_index']!,
          _sourceStartIndexMeta,
        ),
      );
    }
    if (data.containsKey('duration_minutes')) {
      context.handle(
        _durationMinutesMeta,
        durationMinutes.isAcceptableOrUnknown(
          data['duration_minutes']!,
          _durationMinutesMeta,
        ),
      );
    }
    if (data.containsKey('auto_numbering')) {
      context.handle(
        _autoNumberingMeta,
        autoNumbering.isAcceptableOrUnknown(
          data['auto_numbering']!,
          _autoNumberingMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Scene map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Scene(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}project_id'],
      )!,
      number: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}number'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      locationCanonical: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location_canonical'],
      )!,
      locationPureName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location_pure_name'],
      )!,
      locationSiteId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}location_site_id'],
      ),
      locationId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}location_id'],
      ),
      intExt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}int_ext'],
      )!,
      dayNight: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day_night'],
      )!,
      locationColor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location_color'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      actionText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action_text'],
      ),
      sourceStartIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_start_index'],
      ),
      durationMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_minutes'],
      )!,
      autoNumbering: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_numbering'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $ScenesTable createAlias(String alias) {
    return $ScenesTable(attachedDatabase, alias);
  }
}

class Scene extends DataClass implements Insertable<Scene> {
  final int id;
  final int projectId;
  final int number;
  final String name;
  final String locationCanonical;
  final String locationPureName;
  final int? locationSiteId;
  final int? locationId;
  final String intExt;
  final String dayNight;
  final String? locationColor;
  final String? description;
  final String? actionText;
  final int? sourceStartIndex;
  final int durationMinutes;
  final bool autoNumbering;
  final int sortOrder;
  const Scene({
    required this.id,
    required this.projectId,
    required this.number,
    required this.name,
    required this.locationCanonical,
    required this.locationPureName,
    this.locationSiteId,
    this.locationId,
    required this.intExt,
    required this.dayNight,
    this.locationColor,
    this.description,
    this.actionText,
    this.sourceStartIndex,
    required this.durationMinutes,
    required this.autoNumbering,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['project_id'] = Variable<int>(projectId);
    map['number'] = Variable<int>(number);
    map['name'] = Variable<String>(name);
    map['location_canonical'] = Variable<String>(locationCanonical);
    map['location_pure_name'] = Variable<String>(locationPureName);
    if (!nullToAbsent || locationSiteId != null) {
      map['location_site_id'] = Variable<int>(locationSiteId);
    }
    if (!nullToAbsent || locationId != null) {
      map['location_id'] = Variable<int>(locationId);
    }
    map['int_ext'] = Variable<String>(intExt);
    map['day_night'] = Variable<String>(dayNight);
    if (!nullToAbsent || locationColor != null) {
      map['location_color'] = Variable<String>(locationColor);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || actionText != null) {
      map['action_text'] = Variable<String>(actionText);
    }
    if (!nullToAbsent || sourceStartIndex != null) {
      map['source_start_index'] = Variable<int>(sourceStartIndex);
    }
    map['duration_minutes'] = Variable<int>(durationMinutes);
    map['auto_numbering'] = Variable<bool>(autoNumbering);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  ScenesCompanion toCompanion(bool nullToAbsent) {
    return ScenesCompanion(
      id: Value(id),
      projectId: Value(projectId),
      number: Value(number),
      name: Value(name),
      locationCanonical: Value(locationCanonical),
      locationPureName: Value(locationPureName),
      locationSiteId: locationSiteId == null && nullToAbsent
          ? const Value.absent()
          : Value(locationSiteId),
      locationId: locationId == null && nullToAbsent
          ? const Value.absent()
          : Value(locationId),
      intExt: Value(intExt),
      dayNight: Value(dayNight),
      locationColor: locationColor == null && nullToAbsent
          ? const Value.absent()
          : Value(locationColor),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      actionText: actionText == null && nullToAbsent
          ? const Value.absent()
          : Value(actionText),
      sourceStartIndex: sourceStartIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceStartIndex),
      durationMinutes: Value(durationMinutes),
      autoNumbering: Value(autoNumbering),
      sortOrder: Value(sortOrder),
    );
  }

  factory Scene.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Scene(
      id: serializer.fromJson<int>(json['id']),
      projectId: serializer.fromJson<int>(json['projectId']),
      number: serializer.fromJson<int>(json['number']),
      name: serializer.fromJson<String>(json['name']),
      locationCanonical: serializer.fromJson<String>(json['locationCanonical']),
      locationPureName: serializer.fromJson<String>(json['locationPureName']),
      locationSiteId: serializer.fromJson<int?>(json['locationSiteId']),
      locationId: serializer.fromJson<int?>(json['locationId']),
      intExt: serializer.fromJson<String>(json['intExt']),
      dayNight: serializer.fromJson<String>(json['dayNight']),
      locationColor: serializer.fromJson<String?>(json['locationColor']),
      description: serializer.fromJson<String?>(json['description']),
      actionText: serializer.fromJson<String?>(json['actionText']),
      sourceStartIndex: serializer.fromJson<int?>(json['sourceStartIndex']),
      durationMinutes: serializer.fromJson<int>(json['durationMinutes']),
      autoNumbering: serializer.fromJson<bool>(json['autoNumbering']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'projectId': serializer.toJson<int>(projectId),
      'number': serializer.toJson<int>(number),
      'name': serializer.toJson<String>(name),
      'locationCanonical': serializer.toJson<String>(locationCanonical),
      'locationPureName': serializer.toJson<String>(locationPureName),
      'locationSiteId': serializer.toJson<int?>(locationSiteId),
      'locationId': serializer.toJson<int?>(locationId),
      'intExt': serializer.toJson<String>(intExt),
      'dayNight': serializer.toJson<String>(dayNight),
      'locationColor': serializer.toJson<String?>(locationColor),
      'description': serializer.toJson<String?>(description),
      'actionText': serializer.toJson<String?>(actionText),
      'sourceStartIndex': serializer.toJson<int?>(sourceStartIndex),
      'durationMinutes': serializer.toJson<int>(durationMinutes),
      'autoNumbering': serializer.toJson<bool>(autoNumbering),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  Scene copyWith({
    int? id,
    int? projectId,
    int? number,
    String? name,
    String? locationCanonical,
    String? locationPureName,
    Value<int?> locationSiteId = const Value.absent(),
    Value<int?> locationId = const Value.absent(),
    String? intExt,
    String? dayNight,
    Value<String?> locationColor = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<String?> actionText = const Value.absent(),
    Value<int?> sourceStartIndex = const Value.absent(),
    int? durationMinutes,
    bool? autoNumbering,
    int? sortOrder,
  }) => Scene(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    number: number ?? this.number,
    name: name ?? this.name,
    locationCanonical: locationCanonical ?? this.locationCanonical,
    locationPureName: locationPureName ?? this.locationPureName,
    locationSiteId: locationSiteId.present
        ? locationSiteId.value
        : this.locationSiteId,
    locationId: locationId.present ? locationId.value : this.locationId,
    intExt: intExt ?? this.intExt,
    dayNight: dayNight ?? this.dayNight,
    locationColor: locationColor.present
        ? locationColor.value
        : this.locationColor,
    description: description.present ? description.value : this.description,
    actionText: actionText.present ? actionText.value : this.actionText,
    sourceStartIndex: sourceStartIndex.present
        ? sourceStartIndex.value
        : this.sourceStartIndex,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    autoNumbering: autoNumbering ?? this.autoNumbering,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  Scene copyWithCompanion(ScenesCompanion data) {
    return Scene(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      number: data.number.present ? data.number.value : this.number,
      name: data.name.present ? data.name.value : this.name,
      locationCanonical: data.locationCanonical.present
          ? data.locationCanonical.value
          : this.locationCanonical,
      locationPureName: data.locationPureName.present
          ? data.locationPureName.value
          : this.locationPureName,
      locationSiteId: data.locationSiteId.present
          ? data.locationSiteId.value
          : this.locationSiteId,
      locationId: data.locationId.present
          ? data.locationId.value
          : this.locationId,
      intExt: data.intExt.present ? data.intExt.value : this.intExt,
      dayNight: data.dayNight.present ? data.dayNight.value : this.dayNight,
      locationColor: data.locationColor.present
          ? data.locationColor.value
          : this.locationColor,
      description: data.description.present
          ? data.description.value
          : this.description,
      actionText: data.actionText.present
          ? data.actionText.value
          : this.actionText,
      sourceStartIndex: data.sourceStartIndex.present
          ? data.sourceStartIndex.value
          : this.sourceStartIndex,
      durationMinutes: data.durationMinutes.present
          ? data.durationMinutes.value
          : this.durationMinutes,
      autoNumbering: data.autoNumbering.present
          ? data.autoNumbering.value
          : this.autoNumbering,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Scene(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('number: $number, ')
          ..write('name: $name, ')
          ..write('locationCanonical: $locationCanonical, ')
          ..write('locationPureName: $locationPureName, ')
          ..write('locationSiteId: $locationSiteId, ')
          ..write('locationId: $locationId, ')
          ..write('intExt: $intExt, ')
          ..write('dayNight: $dayNight, ')
          ..write('locationColor: $locationColor, ')
          ..write('description: $description, ')
          ..write('actionText: $actionText, ')
          ..write('sourceStartIndex: $sourceStartIndex, ')
          ..write('durationMinutes: $durationMinutes, ')
          ..write('autoNumbering: $autoNumbering, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    number,
    name,
    locationCanonical,
    locationPureName,
    locationSiteId,
    locationId,
    intExt,
    dayNight,
    locationColor,
    description,
    actionText,
    sourceStartIndex,
    durationMinutes,
    autoNumbering,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Scene &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.number == this.number &&
          other.name == this.name &&
          other.locationCanonical == this.locationCanonical &&
          other.locationPureName == this.locationPureName &&
          other.locationSiteId == this.locationSiteId &&
          other.locationId == this.locationId &&
          other.intExt == this.intExt &&
          other.dayNight == this.dayNight &&
          other.locationColor == this.locationColor &&
          other.description == this.description &&
          other.actionText == this.actionText &&
          other.sourceStartIndex == this.sourceStartIndex &&
          other.durationMinutes == this.durationMinutes &&
          other.autoNumbering == this.autoNumbering &&
          other.sortOrder == this.sortOrder);
}

class ScenesCompanion extends UpdateCompanion<Scene> {
  final Value<int> id;
  final Value<int> projectId;
  final Value<int> number;
  final Value<String> name;
  final Value<String> locationCanonical;
  final Value<String> locationPureName;
  final Value<int?> locationSiteId;
  final Value<int?> locationId;
  final Value<String> intExt;
  final Value<String> dayNight;
  final Value<String?> locationColor;
  final Value<String?> description;
  final Value<String?> actionText;
  final Value<int?> sourceStartIndex;
  final Value<int> durationMinutes;
  final Value<bool> autoNumbering;
  final Value<int> sortOrder;
  const ScenesCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.number = const Value.absent(),
    this.name = const Value.absent(),
    this.locationCanonical = const Value.absent(),
    this.locationPureName = const Value.absent(),
    this.locationSiteId = const Value.absent(),
    this.locationId = const Value.absent(),
    this.intExt = const Value.absent(),
    this.dayNight = const Value.absent(),
    this.locationColor = const Value.absent(),
    this.description = const Value.absent(),
    this.actionText = const Value.absent(),
    this.sourceStartIndex = const Value.absent(),
    this.durationMinutes = const Value.absent(),
    this.autoNumbering = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  ScenesCompanion.insert({
    this.id = const Value.absent(),
    required int projectId,
    required int number,
    required String name,
    required String locationCanonical,
    required String locationPureName,
    this.locationSiteId = const Value.absent(),
    this.locationId = const Value.absent(),
    this.intExt = const Value.absent(),
    this.dayNight = const Value.absent(),
    this.locationColor = const Value.absent(),
    this.description = const Value.absent(),
    this.actionText = const Value.absent(),
    this.sourceStartIndex = const Value.absent(),
    this.durationMinutes = const Value.absent(),
    this.autoNumbering = const Value.absent(),
    this.sortOrder = const Value.absent(),
  }) : projectId = Value(projectId),
       number = Value(number),
       name = Value(name),
       locationCanonical = Value(locationCanonical),
       locationPureName = Value(locationPureName);
  static Insertable<Scene> custom({
    Expression<int>? id,
    Expression<int>? projectId,
    Expression<int>? number,
    Expression<String>? name,
    Expression<String>? locationCanonical,
    Expression<String>? locationPureName,
    Expression<int>? locationSiteId,
    Expression<int>? locationId,
    Expression<String>? intExt,
    Expression<String>? dayNight,
    Expression<String>? locationColor,
    Expression<String>? description,
    Expression<String>? actionText,
    Expression<int>? sourceStartIndex,
    Expression<int>? durationMinutes,
    Expression<bool>? autoNumbering,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (number != null) 'number': number,
      if (name != null) 'name': name,
      if (locationCanonical != null) 'location_canonical': locationCanonical,
      if (locationPureName != null) 'location_pure_name': locationPureName,
      if (locationSiteId != null) 'location_site_id': locationSiteId,
      if (locationId != null) 'location_id': locationId,
      if (intExt != null) 'int_ext': intExt,
      if (dayNight != null) 'day_night': dayNight,
      if (locationColor != null) 'location_color': locationColor,
      if (description != null) 'description': description,
      if (actionText != null) 'action_text': actionText,
      if (sourceStartIndex != null) 'source_start_index': sourceStartIndex,
      if (durationMinutes != null) 'duration_minutes': durationMinutes,
      if (autoNumbering != null) 'auto_numbering': autoNumbering,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  ScenesCompanion copyWith({
    Value<int>? id,
    Value<int>? projectId,
    Value<int>? number,
    Value<String>? name,
    Value<String>? locationCanonical,
    Value<String>? locationPureName,
    Value<int?>? locationSiteId,
    Value<int?>? locationId,
    Value<String>? intExt,
    Value<String>? dayNight,
    Value<String?>? locationColor,
    Value<String?>? description,
    Value<String?>? actionText,
    Value<int?>? sourceStartIndex,
    Value<int>? durationMinutes,
    Value<bool>? autoNumbering,
    Value<int>? sortOrder,
  }) {
    return ScenesCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      number: number ?? this.number,
      name: name ?? this.name,
      locationCanonical: locationCanonical ?? this.locationCanonical,
      locationPureName: locationPureName ?? this.locationPureName,
      locationSiteId: locationSiteId ?? this.locationSiteId,
      locationId: locationId ?? this.locationId,
      intExt: intExt ?? this.intExt,
      dayNight: dayNight ?? this.dayNight,
      locationColor: locationColor ?? this.locationColor,
      description: description ?? this.description,
      actionText: actionText ?? this.actionText,
      sourceStartIndex: sourceStartIndex ?? this.sourceStartIndex,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      autoNumbering: autoNumbering ?? this.autoNumbering,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<int>(projectId.value);
    }
    if (number.present) {
      map['number'] = Variable<int>(number.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (locationCanonical.present) {
      map['location_canonical'] = Variable<String>(locationCanonical.value);
    }
    if (locationPureName.present) {
      map['location_pure_name'] = Variable<String>(locationPureName.value);
    }
    if (locationSiteId.present) {
      map['location_site_id'] = Variable<int>(locationSiteId.value);
    }
    if (locationId.present) {
      map['location_id'] = Variable<int>(locationId.value);
    }
    if (intExt.present) {
      map['int_ext'] = Variable<String>(intExt.value);
    }
    if (dayNight.present) {
      map['day_night'] = Variable<String>(dayNight.value);
    }
    if (locationColor.present) {
      map['location_color'] = Variable<String>(locationColor.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (actionText.present) {
      map['action_text'] = Variable<String>(actionText.value);
    }
    if (sourceStartIndex.present) {
      map['source_start_index'] = Variable<int>(sourceStartIndex.value);
    }
    if (durationMinutes.present) {
      map['duration_minutes'] = Variable<int>(durationMinutes.value);
    }
    if (autoNumbering.present) {
      map['auto_numbering'] = Variable<bool>(autoNumbering.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScenesCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('number: $number, ')
          ..write('name: $name, ')
          ..write('locationCanonical: $locationCanonical, ')
          ..write('locationPureName: $locationPureName, ')
          ..write('locationSiteId: $locationSiteId, ')
          ..write('locationId: $locationId, ')
          ..write('intExt: $intExt, ')
          ..write('dayNight: $dayNight, ')
          ..write('locationColor: $locationColor, ')
          ..write('description: $description, ')
          ..write('actionText: $actionText, ')
          ..write('sourceStartIndex: $sourceStartIndex, ')
          ..write('durationMinutes: $durationMinutes, ')
          ..write('autoNumbering: $autoNumbering, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }
}

class $ShotsTable extends Shots with TableInfo<$ShotsTable, Shot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sceneIdMeta = const VerificationMeta(
    'sceneId',
  );
  @override
  late final GeneratedColumn<int> sceneId = GeneratedColumn<int>(
    'scene_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES scenes (id)',
    ),
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<int> projectId = GeneratedColumn<int>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id)',
    ),
  );
  static const VerificationMeta _numberMeta = const VerificationMeta('number');
  @override
  late final GeneratedColumn<int> number = GeneratedColumn<int>(
    'number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _framingMeta = const VerificationMeta(
    'framing',
  );
  @override
  late final GeneratedColumn<String> framing = GeneratedColumn<String>(
    'framing',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lensMeta = const VerificationMeta('lens');
  @override
  late final GeneratedColumn<String> lens = GeneratedColumn<String>(
    'lens',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _angleMeta = const VerificationMeta('angle');
  @override
  late final GeneratedColumn<String> angle = GeneratedColumn<String>(
    'angle',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _movementMeta = const VerificationMeta(
    'movement',
  );
  @override
  late final GeneratedColumn<String> movement = GeneratedColumn<String>(
    'movement',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fStopMeta = const VerificationMeta('fStop');
  @override
  late final GeneratedColumn<String> fStop = GeneratedColumn<String>(
    'f_stop',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _shutterAngleMeta = const VerificationMeta(
    'shutterAngle',
  );
  @override
  late final GeneratedColumn<String> shutterAngle = GeneratedColumn<String>(
    'shutter_angle',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fpsMeta = const VerificationMeta('fps');
  @override
  late final GeneratedColumn<int> fps = GeneratedColumn<int>(
    'fps',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesHighlightMeta = const VerificationMeta(
    'notesHighlight',
  );
  @override
  late final GeneratedColumn<String> notesHighlight = GeneratedColumn<String>(
    'notes_highlight',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _referenceImagePathMeta =
      const VerificationMeta('referenceImagePath');
  @override
  late final GeneratedColumn<String> referenceImagePath =
      GeneratedColumn<String>(
        'reference_image_path',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _cameraPlanImagePathMeta =
      const VerificationMeta('cameraPlanImagePath');
  @override
  late final GeneratedColumn<String> cameraPlanImagePath =
      GeneratedColumn<String>(
        'camera_plan_image_path',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _autoNumberingMeta = const VerificationMeta(
    'autoNumbering',
  );
  @override
  late final GeneratedColumn<bool> autoNumbering = GeneratedColumn<bool>(
    'auto_numbering',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("auto_numbering" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sceneId,
    projectId,
    number,
    framing,
    lens,
    angle,
    movement,
    fStop,
    shutterAngle,
    fps,
    action,
    notes,
    notesHighlight,
    description,
    referenceImagePath,
    cameraPlanImagePath,
    autoNumbering,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shots';
  @override
  VerificationContext validateIntegrity(
    Insertable<Shot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('scene_id')) {
      context.handle(
        _sceneIdMeta,
        sceneId.isAcceptableOrUnknown(data['scene_id']!, _sceneIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sceneIdMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('number')) {
      context.handle(
        _numberMeta,
        number.isAcceptableOrUnknown(data['number']!, _numberMeta),
      );
    } else if (isInserting) {
      context.missing(_numberMeta);
    }
    if (data.containsKey('framing')) {
      context.handle(
        _framingMeta,
        framing.isAcceptableOrUnknown(data['framing']!, _framingMeta),
      );
    }
    if (data.containsKey('lens')) {
      context.handle(
        _lensMeta,
        lens.isAcceptableOrUnknown(data['lens']!, _lensMeta),
      );
    }
    if (data.containsKey('angle')) {
      context.handle(
        _angleMeta,
        angle.isAcceptableOrUnknown(data['angle']!, _angleMeta),
      );
    }
    if (data.containsKey('movement')) {
      context.handle(
        _movementMeta,
        movement.isAcceptableOrUnknown(data['movement']!, _movementMeta),
      );
    }
    if (data.containsKey('f_stop')) {
      context.handle(
        _fStopMeta,
        fStop.isAcceptableOrUnknown(data['f_stop']!, _fStopMeta),
      );
    }
    if (data.containsKey('shutter_angle')) {
      context.handle(
        _shutterAngleMeta,
        shutterAngle.isAcceptableOrUnknown(
          data['shutter_angle']!,
          _shutterAngleMeta,
        ),
      );
    }
    if (data.containsKey('fps')) {
      context.handle(
        _fpsMeta,
        fps.isAcceptableOrUnknown(data['fps']!, _fpsMeta),
      );
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('notes_highlight')) {
      context.handle(
        _notesHighlightMeta,
        notesHighlight.isAcceptableOrUnknown(
          data['notes_highlight']!,
          _notesHighlightMeta,
        ),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('reference_image_path')) {
      context.handle(
        _referenceImagePathMeta,
        referenceImagePath.isAcceptableOrUnknown(
          data['reference_image_path']!,
          _referenceImagePathMeta,
        ),
      );
    }
    if (data.containsKey('camera_plan_image_path')) {
      context.handle(
        _cameraPlanImagePathMeta,
        cameraPlanImagePath.isAcceptableOrUnknown(
          data['camera_plan_image_path']!,
          _cameraPlanImagePathMeta,
        ),
      );
    }
    if (data.containsKey('auto_numbering')) {
      context.handle(
        _autoNumberingMeta,
        autoNumbering.isAcceptableOrUnknown(
          data['auto_numbering']!,
          _autoNumberingMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Shot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Shot(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sceneId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scene_id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}project_id'],
      )!,
      number: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}number'],
      )!,
      framing: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}framing'],
      ),
      lens: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lens'],
      ),
      angle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}angle'],
      ),
      movement: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}movement'],
      ),
      fStop: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}f_stop'],
      ),
      shutterAngle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shutter_angle'],
      ),
      fps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fps'],
      ),
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      notesHighlight: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes_highlight'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      referenceImagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference_image_path'],
      ),
      cameraPlanImagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}camera_plan_image_path'],
      ),
      autoNumbering: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_numbering'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $ShotsTable createAlias(String alias) {
    return $ShotsTable(attachedDatabase, alias);
  }
}

class Shot extends DataClass implements Insertable<Shot> {
  final int id;
  final int sceneId;
  final int projectId;
  final int number;
  final String? framing;
  final String? lens;
  final String? angle;
  final String? movement;
  final String? fStop;
  final String? shutterAngle;
  final int? fps;
  final String? action;
  final String? notes;
  final String? notesHighlight;
  final String? description;
  final String? referenceImagePath;
  final String? cameraPlanImagePath;
  final bool autoNumbering;
  final int sortOrder;
  const Shot({
    required this.id,
    required this.sceneId,
    required this.projectId,
    required this.number,
    this.framing,
    this.lens,
    this.angle,
    this.movement,
    this.fStop,
    this.shutterAngle,
    this.fps,
    this.action,
    this.notes,
    this.notesHighlight,
    this.description,
    this.referenceImagePath,
    this.cameraPlanImagePath,
    required this.autoNumbering,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['scene_id'] = Variable<int>(sceneId);
    map['project_id'] = Variable<int>(projectId);
    map['number'] = Variable<int>(number);
    if (!nullToAbsent || framing != null) {
      map['framing'] = Variable<String>(framing);
    }
    if (!nullToAbsent || lens != null) {
      map['lens'] = Variable<String>(lens);
    }
    if (!nullToAbsent || angle != null) {
      map['angle'] = Variable<String>(angle);
    }
    if (!nullToAbsent || movement != null) {
      map['movement'] = Variable<String>(movement);
    }
    if (!nullToAbsent || fStop != null) {
      map['f_stop'] = Variable<String>(fStop);
    }
    if (!nullToAbsent || shutterAngle != null) {
      map['shutter_angle'] = Variable<String>(shutterAngle);
    }
    if (!nullToAbsent || fps != null) {
      map['fps'] = Variable<int>(fps);
    }
    if (!nullToAbsent || action != null) {
      map['action'] = Variable<String>(action);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || notesHighlight != null) {
      map['notes_highlight'] = Variable<String>(notesHighlight);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || referenceImagePath != null) {
      map['reference_image_path'] = Variable<String>(referenceImagePath);
    }
    if (!nullToAbsent || cameraPlanImagePath != null) {
      map['camera_plan_image_path'] = Variable<String>(cameraPlanImagePath);
    }
    map['auto_numbering'] = Variable<bool>(autoNumbering);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  ShotsCompanion toCompanion(bool nullToAbsent) {
    return ShotsCompanion(
      id: Value(id),
      sceneId: Value(sceneId),
      projectId: Value(projectId),
      number: Value(number),
      framing: framing == null && nullToAbsent
          ? const Value.absent()
          : Value(framing),
      lens: lens == null && nullToAbsent ? const Value.absent() : Value(lens),
      angle: angle == null && nullToAbsent
          ? const Value.absent()
          : Value(angle),
      movement: movement == null && nullToAbsent
          ? const Value.absent()
          : Value(movement),
      fStop: fStop == null && nullToAbsent
          ? const Value.absent()
          : Value(fStop),
      shutterAngle: shutterAngle == null && nullToAbsent
          ? const Value.absent()
          : Value(shutterAngle),
      fps: fps == null && nullToAbsent ? const Value.absent() : Value(fps),
      action: action == null && nullToAbsent
          ? const Value.absent()
          : Value(action),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      notesHighlight: notesHighlight == null && nullToAbsent
          ? const Value.absent()
          : Value(notesHighlight),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      referenceImagePath: referenceImagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(referenceImagePath),
      cameraPlanImagePath: cameraPlanImagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(cameraPlanImagePath),
      autoNumbering: Value(autoNumbering),
      sortOrder: Value(sortOrder),
    );
  }

  factory Shot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Shot(
      id: serializer.fromJson<int>(json['id']),
      sceneId: serializer.fromJson<int>(json['sceneId']),
      projectId: serializer.fromJson<int>(json['projectId']),
      number: serializer.fromJson<int>(json['number']),
      framing: serializer.fromJson<String?>(json['framing']),
      lens: serializer.fromJson<String?>(json['lens']),
      angle: serializer.fromJson<String?>(json['angle']),
      movement: serializer.fromJson<String?>(json['movement']),
      fStop: serializer.fromJson<String?>(json['fStop']),
      shutterAngle: serializer.fromJson<String?>(json['shutterAngle']),
      fps: serializer.fromJson<int?>(json['fps']),
      action: serializer.fromJson<String?>(json['action']),
      notes: serializer.fromJson<String?>(json['notes']),
      notesHighlight: serializer.fromJson<String?>(json['notesHighlight']),
      description: serializer.fromJson<String?>(json['description']),
      referenceImagePath: serializer.fromJson<String?>(
        json['referenceImagePath'],
      ),
      cameraPlanImagePath: serializer.fromJson<String?>(
        json['cameraPlanImagePath'],
      ),
      autoNumbering: serializer.fromJson<bool>(json['autoNumbering']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sceneId': serializer.toJson<int>(sceneId),
      'projectId': serializer.toJson<int>(projectId),
      'number': serializer.toJson<int>(number),
      'framing': serializer.toJson<String?>(framing),
      'lens': serializer.toJson<String?>(lens),
      'angle': serializer.toJson<String?>(angle),
      'movement': serializer.toJson<String?>(movement),
      'fStop': serializer.toJson<String?>(fStop),
      'shutterAngle': serializer.toJson<String?>(shutterAngle),
      'fps': serializer.toJson<int?>(fps),
      'action': serializer.toJson<String?>(action),
      'notes': serializer.toJson<String?>(notes),
      'notesHighlight': serializer.toJson<String?>(notesHighlight),
      'description': serializer.toJson<String?>(description),
      'referenceImagePath': serializer.toJson<String?>(referenceImagePath),
      'cameraPlanImagePath': serializer.toJson<String?>(cameraPlanImagePath),
      'autoNumbering': serializer.toJson<bool>(autoNumbering),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  Shot copyWith({
    int? id,
    int? sceneId,
    int? projectId,
    int? number,
    Value<String?> framing = const Value.absent(),
    Value<String?> lens = const Value.absent(),
    Value<String?> angle = const Value.absent(),
    Value<String?> movement = const Value.absent(),
    Value<String?> fStop = const Value.absent(),
    Value<String?> shutterAngle = const Value.absent(),
    Value<int?> fps = const Value.absent(),
    Value<String?> action = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<String?> notesHighlight = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<String?> referenceImagePath = const Value.absent(),
    Value<String?> cameraPlanImagePath = const Value.absent(),
    bool? autoNumbering,
    int? sortOrder,
  }) => Shot(
    id: id ?? this.id,
    sceneId: sceneId ?? this.sceneId,
    projectId: projectId ?? this.projectId,
    number: number ?? this.number,
    framing: framing.present ? framing.value : this.framing,
    lens: lens.present ? lens.value : this.lens,
    angle: angle.present ? angle.value : this.angle,
    movement: movement.present ? movement.value : this.movement,
    fStop: fStop.present ? fStop.value : this.fStop,
    shutterAngle: shutterAngle.present ? shutterAngle.value : this.shutterAngle,
    fps: fps.present ? fps.value : this.fps,
    action: action.present ? action.value : this.action,
    notes: notes.present ? notes.value : this.notes,
    notesHighlight: notesHighlight.present
        ? notesHighlight.value
        : this.notesHighlight,
    description: description.present ? description.value : this.description,
    referenceImagePath: referenceImagePath.present
        ? referenceImagePath.value
        : this.referenceImagePath,
    cameraPlanImagePath: cameraPlanImagePath.present
        ? cameraPlanImagePath.value
        : this.cameraPlanImagePath,
    autoNumbering: autoNumbering ?? this.autoNumbering,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  Shot copyWithCompanion(ShotsCompanion data) {
    return Shot(
      id: data.id.present ? data.id.value : this.id,
      sceneId: data.sceneId.present ? data.sceneId.value : this.sceneId,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      number: data.number.present ? data.number.value : this.number,
      framing: data.framing.present ? data.framing.value : this.framing,
      lens: data.lens.present ? data.lens.value : this.lens,
      angle: data.angle.present ? data.angle.value : this.angle,
      movement: data.movement.present ? data.movement.value : this.movement,
      fStop: data.fStop.present ? data.fStop.value : this.fStop,
      shutterAngle: data.shutterAngle.present
          ? data.shutterAngle.value
          : this.shutterAngle,
      fps: data.fps.present ? data.fps.value : this.fps,
      action: data.action.present ? data.action.value : this.action,
      notes: data.notes.present ? data.notes.value : this.notes,
      notesHighlight: data.notesHighlight.present
          ? data.notesHighlight.value
          : this.notesHighlight,
      description: data.description.present
          ? data.description.value
          : this.description,
      referenceImagePath: data.referenceImagePath.present
          ? data.referenceImagePath.value
          : this.referenceImagePath,
      cameraPlanImagePath: data.cameraPlanImagePath.present
          ? data.cameraPlanImagePath.value
          : this.cameraPlanImagePath,
      autoNumbering: data.autoNumbering.present
          ? data.autoNumbering.value
          : this.autoNumbering,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Shot(')
          ..write('id: $id, ')
          ..write('sceneId: $sceneId, ')
          ..write('projectId: $projectId, ')
          ..write('number: $number, ')
          ..write('framing: $framing, ')
          ..write('lens: $lens, ')
          ..write('angle: $angle, ')
          ..write('movement: $movement, ')
          ..write('fStop: $fStop, ')
          ..write('shutterAngle: $shutterAngle, ')
          ..write('fps: $fps, ')
          ..write('action: $action, ')
          ..write('notes: $notes, ')
          ..write('notesHighlight: $notesHighlight, ')
          ..write('description: $description, ')
          ..write('referenceImagePath: $referenceImagePath, ')
          ..write('cameraPlanImagePath: $cameraPlanImagePath, ')
          ..write('autoNumbering: $autoNumbering, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sceneId,
    projectId,
    number,
    framing,
    lens,
    angle,
    movement,
    fStop,
    shutterAngle,
    fps,
    action,
    notes,
    notesHighlight,
    description,
    referenceImagePath,
    cameraPlanImagePath,
    autoNumbering,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Shot &&
          other.id == this.id &&
          other.sceneId == this.sceneId &&
          other.projectId == this.projectId &&
          other.number == this.number &&
          other.framing == this.framing &&
          other.lens == this.lens &&
          other.angle == this.angle &&
          other.movement == this.movement &&
          other.fStop == this.fStop &&
          other.shutterAngle == this.shutterAngle &&
          other.fps == this.fps &&
          other.action == this.action &&
          other.notes == this.notes &&
          other.notesHighlight == this.notesHighlight &&
          other.description == this.description &&
          other.referenceImagePath == this.referenceImagePath &&
          other.cameraPlanImagePath == this.cameraPlanImagePath &&
          other.autoNumbering == this.autoNumbering &&
          other.sortOrder == this.sortOrder);
}

class ShotsCompanion extends UpdateCompanion<Shot> {
  final Value<int> id;
  final Value<int> sceneId;
  final Value<int> projectId;
  final Value<int> number;
  final Value<String?> framing;
  final Value<String?> lens;
  final Value<String?> angle;
  final Value<String?> movement;
  final Value<String?> fStop;
  final Value<String?> shutterAngle;
  final Value<int?> fps;
  final Value<String?> action;
  final Value<String?> notes;
  final Value<String?> notesHighlight;
  final Value<String?> description;
  final Value<String?> referenceImagePath;
  final Value<String?> cameraPlanImagePath;
  final Value<bool> autoNumbering;
  final Value<int> sortOrder;
  const ShotsCompanion({
    this.id = const Value.absent(),
    this.sceneId = const Value.absent(),
    this.projectId = const Value.absent(),
    this.number = const Value.absent(),
    this.framing = const Value.absent(),
    this.lens = const Value.absent(),
    this.angle = const Value.absent(),
    this.movement = const Value.absent(),
    this.fStop = const Value.absent(),
    this.shutterAngle = const Value.absent(),
    this.fps = const Value.absent(),
    this.action = const Value.absent(),
    this.notes = const Value.absent(),
    this.notesHighlight = const Value.absent(),
    this.description = const Value.absent(),
    this.referenceImagePath = const Value.absent(),
    this.cameraPlanImagePath = const Value.absent(),
    this.autoNumbering = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  ShotsCompanion.insert({
    this.id = const Value.absent(),
    required int sceneId,
    required int projectId,
    required int number,
    this.framing = const Value.absent(),
    this.lens = const Value.absent(),
    this.angle = const Value.absent(),
    this.movement = const Value.absent(),
    this.fStop = const Value.absent(),
    this.shutterAngle = const Value.absent(),
    this.fps = const Value.absent(),
    this.action = const Value.absent(),
    this.notes = const Value.absent(),
    this.notesHighlight = const Value.absent(),
    this.description = const Value.absent(),
    this.referenceImagePath = const Value.absent(),
    this.cameraPlanImagePath = const Value.absent(),
    this.autoNumbering = const Value.absent(),
    this.sortOrder = const Value.absent(),
  }) : sceneId = Value(sceneId),
       projectId = Value(projectId),
       number = Value(number);
  static Insertable<Shot> custom({
    Expression<int>? id,
    Expression<int>? sceneId,
    Expression<int>? projectId,
    Expression<int>? number,
    Expression<String>? framing,
    Expression<String>? lens,
    Expression<String>? angle,
    Expression<String>? movement,
    Expression<String>? fStop,
    Expression<String>? shutterAngle,
    Expression<int>? fps,
    Expression<String>? action,
    Expression<String>? notes,
    Expression<String>? notesHighlight,
    Expression<String>? description,
    Expression<String>? referenceImagePath,
    Expression<String>? cameraPlanImagePath,
    Expression<bool>? autoNumbering,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sceneId != null) 'scene_id': sceneId,
      if (projectId != null) 'project_id': projectId,
      if (number != null) 'number': number,
      if (framing != null) 'framing': framing,
      if (lens != null) 'lens': lens,
      if (angle != null) 'angle': angle,
      if (movement != null) 'movement': movement,
      if (fStop != null) 'f_stop': fStop,
      if (shutterAngle != null) 'shutter_angle': shutterAngle,
      if (fps != null) 'fps': fps,
      if (action != null) 'action': action,
      if (notes != null) 'notes': notes,
      if (notesHighlight != null) 'notes_highlight': notesHighlight,
      if (description != null) 'description': description,
      if (referenceImagePath != null)
        'reference_image_path': referenceImagePath,
      if (cameraPlanImagePath != null)
        'camera_plan_image_path': cameraPlanImagePath,
      if (autoNumbering != null) 'auto_numbering': autoNumbering,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  ShotsCompanion copyWith({
    Value<int>? id,
    Value<int>? sceneId,
    Value<int>? projectId,
    Value<int>? number,
    Value<String?>? framing,
    Value<String?>? lens,
    Value<String?>? angle,
    Value<String?>? movement,
    Value<String?>? fStop,
    Value<String?>? shutterAngle,
    Value<int?>? fps,
    Value<String?>? action,
    Value<String?>? notes,
    Value<String?>? notesHighlight,
    Value<String?>? description,
    Value<String?>? referenceImagePath,
    Value<String?>? cameraPlanImagePath,
    Value<bool>? autoNumbering,
    Value<int>? sortOrder,
  }) {
    return ShotsCompanion(
      id: id ?? this.id,
      sceneId: sceneId ?? this.sceneId,
      projectId: projectId ?? this.projectId,
      number: number ?? this.number,
      framing: framing ?? this.framing,
      lens: lens ?? this.lens,
      angle: angle ?? this.angle,
      movement: movement ?? this.movement,
      fStop: fStop ?? this.fStop,
      shutterAngle: shutterAngle ?? this.shutterAngle,
      fps: fps ?? this.fps,
      action: action ?? this.action,
      notes: notes ?? this.notes,
      notesHighlight: notesHighlight ?? this.notesHighlight,
      description: description ?? this.description,
      referenceImagePath: referenceImagePath ?? this.referenceImagePath,
      cameraPlanImagePath: cameraPlanImagePath ?? this.cameraPlanImagePath,
      autoNumbering: autoNumbering ?? this.autoNumbering,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sceneId.present) {
      map['scene_id'] = Variable<int>(sceneId.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<int>(projectId.value);
    }
    if (number.present) {
      map['number'] = Variable<int>(number.value);
    }
    if (framing.present) {
      map['framing'] = Variable<String>(framing.value);
    }
    if (lens.present) {
      map['lens'] = Variable<String>(lens.value);
    }
    if (angle.present) {
      map['angle'] = Variable<String>(angle.value);
    }
    if (movement.present) {
      map['movement'] = Variable<String>(movement.value);
    }
    if (fStop.present) {
      map['f_stop'] = Variable<String>(fStop.value);
    }
    if (shutterAngle.present) {
      map['shutter_angle'] = Variable<String>(shutterAngle.value);
    }
    if (fps.present) {
      map['fps'] = Variable<int>(fps.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (notesHighlight.present) {
      map['notes_highlight'] = Variable<String>(notesHighlight.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (referenceImagePath.present) {
      map['reference_image_path'] = Variable<String>(referenceImagePath.value);
    }
    if (cameraPlanImagePath.present) {
      map['camera_plan_image_path'] = Variable<String>(
        cameraPlanImagePath.value,
      );
    }
    if (autoNumbering.present) {
      map['auto_numbering'] = Variable<bool>(autoNumbering.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShotsCompanion(')
          ..write('id: $id, ')
          ..write('sceneId: $sceneId, ')
          ..write('projectId: $projectId, ')
          ..write('number: $number, ')
          ..write('framing: $framing, ')
          ..write('lens: $lens, ')
          ..write('angle: $angle, ')
          ..write('movement: $movement, ')
          ..write('fStop: $fStop, ')
          ..write('shutterAngle: $shutterAngle, ')
          ..write('fps: $fps, ')
          ..write('action: $action, ')
          ..write('notes: $notes, ')
          ..write('notesHighlight: $notesHighlight, ')
          ..write('description: $description, ')
          ..write('referenceImagePath: $referenceImagePath, ')
          ..write('cameraPlanImagePath: $cameraPlanImagePath, ')
          ..write('autoNumbering: $autoNumbering, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }
}

class $ShotReferencesTable extends ShotReferences
    with TableInfo<$ShotReferencesTable, ShotReference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShotReferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _shotIdMeta = const VerificationMeta('shotId');
  @override
  late final GeneratedColumn<int> shotId = GeneratedColumn<int>(
    'shot_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES shots (id)',
    ),
  );
  static const VerificationMeta _imagePathMeta = const VerificationMeta(
    'imagePath',
  );
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
    'image_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    shotId,
    imagePath,
    source,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shot_references';
  @override
  VerificationContext validateIntegrity(
    Insertable<ShotReference> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('shot_id')) {
      context.handle(
        _shotIdMeta,
        shotId.isAcceptableOrUnknown(data['shot_id']!, _shotIdMeta),
      );
    } else if (isInserting) {
      context.missing(_shotIdMeta);
    }
    if (data.containsKey('image_path')) {
      context.handle(
        _imagePathMeta,
        imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta),
      );
    } else if (isInserting) {
      context.missing(_imagePathMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ShotReference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShotReference(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      shotId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}shot_id'],
      )!,
      imagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_path'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $ShotReferencesTable createAlias(String alias) {
    return $ShotReferencesTable(attachedDatabase, alias);
  }
}

class ShotReference extends DataClass implements Insertable<ShotReference> {
  final int id;
  final int shotId;
  final String imagePath;
  final String source;
  final int sortOrder;
  const ShotReference({
    required this.id,
    required this.shotId,
    required this.imagePath,
    required this.source,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['shot_id'] = Variable<int>(shotId);
    map['image_path'] = Variable<String>(imagePath);
    map['source'] = Variable<String>(source);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  ShotReferencesCompanion toCompanion(bool nullToAbsent) {
    return ShotReferencesCompanion(
      id: Value(id),
      shotId: Value(shotId),
      imagePath: Value(imagePath),
      source: Value(source),
      sortOrder: Value(sortOrder),
    );
  }

  factory ShotReference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShotReference(
      id: serializer.fromJson<int>(json['id']),
      shotId: serializer.fromJson<int>(json['shotId']),
      imagePath: serializer.fromJson<String>(json['imagePath']),
      source: serializer.fromJson<String>(json['source']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'shotId': serializer.toJson<int>(shotId),
      'imagePath': serializer.toJson<String>(imagePath),
      'source': serializer.toJson<String>(source),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  ShotReference copyWith({
    int? id,
    int? shotId,
    String? imagePath,
    String? source,
    int? sortOrder,
  }) => ShotReference(
    id: id ?? this.id,
    shotId: shotId ?? this.shotId,
    imagePath: imagePath ?? this.imagePath,
    source: source ?? this.source,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  ShotReference copyWithCompanion(ShotReferencesCompanion data) {
    return ShotReference(
      id: data.id.present ? data.id.value : this.id,
      shotId: data.shotId.present ? data.shotId.value : this.shotId,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      source: data.source.present ? data.source.value : this.source,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShotReference(')
          ..write('id: $id, ')
          ..write('shotId: $shotId, ')
          ..write('imagePath: $imagePath, ')
          ..write('source: $source, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, shotId, imagePath, source, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShotReference &&
          other.id == this.id &&
          other.shotId == this.shotId &&
          other.imagePath == this.imagePath &&
          other.source == this.source &&
          other.sortOrder == this.sortOrder);
}

class ShotReferencesCompanion extends UpdateCompanion<ShotReference> {
  final Value<int> id;
  final Value<int> shotId;
  final Value<String> imagePath;
  final Value<String> source;
  final Value<int> sortOrder;
  const ShotReferencesCompanion({
    this.id = const Value.absent(),
    this.shotId = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.source = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  ShotReferencesCompanion.insert({
    this.id = const Value.absent(),
    required int shotId,
    required String imagePath,
    this.source = const Value.absent(),
    this.sortOrder = const Value.absent(),
  }) : shotId = Value(shotId),
       imagePath = Value(imagePath);
  static Insertable<ShotReference> custom({
    Expression<int>? id,
    Expression<int>? shotId,
    Expression<String>? imagePath,
    Expression<String>? source,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (shotId != null) 'shot_id': shotId,
      if (imagePath != null) 'image_path': imagePath,
      if (source != null) 'source': source,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  ShotReferencesCompanion copyWith({
    Value<int>? id,
    Value<int>? shotId,
    Value<String>? imagePath,
    Value<String>? source,
    Value<int>? sortOrder,
  }) {
    return ShotReferencesCompanion(
      id: id ?? this.id,
      shotId: shotId ?? this.shotId,
      imagePath: imagePath ?? this.imagePath,
      source: source ?? this.source,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (shotId.present) {
      map['shot_id'] = Variable<int>(shotId.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShotReferencesCompanion(')
          ..write('id: $id, ')
          ..write('shotId: $shotId, ')
          ..write('imagePath: $imagePath, ')
          ..write('source: $source, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }
}

class $CameraPlanElementsTable extends CameraPlanElements
    with TableInfo<$CameraPlanElementsTable, CameraPlanElement> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CameraPlanElementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _shotIdMeta = const VerificationMeta('shotId');
  @override
  late final GeneratedColumn<int> shotId = GeneratedColumn<int>(
    'shot_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES shots (id)',
    ),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _xMeta = const VerificationMeta('x');
  @override
  late final GeneratedColumn<double> x = GeneratedColumn<double>(
    'x',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _yMeta = const VerificationMeta('y');
  @override
  late final GeneratedColumn<double> y = GeneratedColumn<double>(
    'y',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _rotationMeta = const VerificationMeta(
    'rotation',
  );
  @override
  late final GeneratedColumn<double> rotation = GeneratedColumn<double>(
    'rotation',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cameraStabilizationMeta =
      const VerificationMeta('cameraStabilization');
  @override
  late final GeneratedColumn<String> cameraStabilization =
      GeneratedColumn<String>(
        'camera_stabilization',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _cameraLensMeta = const VerificationMeta(
    'cameraLens',
  );
  @override
  late final GeneratedColumn<String> cameraLens = GeneratedColumn<String>(
    'camera_lens',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cameraLetterMeta = const VerificationMeta(
    'cameraLetter',
  );
  @override
  late final GeneratedColumn<String> cameraLetter = GeneratedColumn<String>(
    'camera_letter',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('A'),
  );
  static const VerificationMeta _cameraNumberMeta = const VerificationMeta(
    'cameraNumber',
  );
  @override
  late final GeneratedColumn<int> cameraNumber = GeneratedColumn<int>(
    'camera_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _lightTypeMeta = const VerificationMeta(
    'lightType',
  );
  @override
  late final GeneratedColumn<String> lightType = GeneratedColumn<String>(
    'light_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lukaCompatibleMeta = const VerificationMeta(
    'lukaCompatible',
  );
  @override
  late final GeneratedColumn<bool> lukaCompatible = GeneratedColumn<bool>(
    'luka_compatible',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("luka_compatible" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lukaFixtureIdMeta = const VerificationMeta(
    'lukaFixtureId',
  );
  @override
  late final GeneratedColumn<String> lukaFixtureId = GeneratedColumn<String>(
    'luka_fixture_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _externalMappingJsonMeta =
      const VerificationMeta('externalMappingJson');
  @override
  late final GeneratedColumn<String> externalMappingJson =
      GeneratedColumn<String>(
        'external_mapping_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    shotId,
    type,
    x,
    y,
    rotation,
    label,
    color,
    cameraStabilization,
    cameraLens,
    cameraLetter,
    cameraNumber,
    lightType,
    lukaCompatible,
    lukaFixtureId,
    externalMappingJson,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'camera_plan_elements';
  @override
  VerificationContext validateIntegrity(
    Insertable<CameraPlanElement> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('shot_id')) {
      context.handle(
        _shotIdMeta,
        shotId.isAcceptableOrUnknown(data['shot_id']!, _shotIdMeta),
      );
    } else if (isInserting) {
      context.missing(_shotIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('x')) {
      context.handle(_xMeta, x.isAcceptableOrUnknown(data['x']!, _xMeta));
    }
    if (data.containsKey('y')) {
      context.handle(_yMeta, y.isAcceptableOrUnknown(data['y']!, _yMeta));
    }
    if (data.containsKey('rotation')) {
      context.handle(
        _rotationMeta,
        rotation.isAcceptableOrUnknown(data['rotation']!, _rotationMeta),
      );
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('camera_stabilization')) {
      context.handle(
        _cameraStabilizationMeta,
        cameraStabilization.isAcceptableOrUnknown(
          data['camera_stabilization']!,
          _cameraStabilizationMeta,
        ),
      );
    }
    if (data.containsKey('camera_lens')) {
      context.handle(
        _cameraLensMeta,
        cameraLens.isAcceptableOrUnknown(data['camera_lens']!, _cameraLensMeta),
      );
    }
    if (data.containsKey('camera_letter')) {
      context.handle(
        _cameraLetterMeta,
        cameraLetter.isAcceptableOrUnknown(
          data['camera_letter']!,
          _cameraLetterMeta,
        ),
      );
    }
    if (data.containsKey('camera_number')) {
      context.handle(
        _cameraNumberMeta,
        cameraNumber.isAcceptableOrUnknown(
          data['camera_number']!,
          _cameraNumberMeta,
        ),
      );
    }
    if (data.containsKey('light_type')) {
      context.handle(
        _lightTypeMeta,
        lightType.isAcceptableOrUnknown(data['light_type']!, _lightTypeMeta),
      );
    }
    if (data.containsKey('luka_compatible')) {
      context.handle(
        _lukaCompatibleMeta,
        lukaCompatible.isAcceptableOrUnknown(
          data['luka_compatible']!,
          _lukaCompatibleMeta,
        ),
      );
    }
    if (data.containsKey('luka_fixture_id')) {
      context.handle(
        _lukaFixtureIdMeta,
        lukaFixtureId.isAcceptableOrUnknown(
          data['luka_fixture_id']!,
          _lukaFixtureIdMeta,
        ),
      );
    }
    if (data.containsKey('external_mapping_json')) {
      context.handle(
        _externalMappingJsonMeta,
        externalMappingJson.isAcceptableOrUnknown(
          data['external_mapping_json']!,
          _externalMappingJsonMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CameraPlanElement map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CameraPlanElement(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      shotId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}shot_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      x: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}x'],
      )!,
      y: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}y'],
      )!,
      rotation: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rotation'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      ),
      cameraStabilization: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}camera_stabilization'],
      ),
      cameraLens: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}camera_lens'],
      ),
      cameraLetter: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}camera_letter'],
      )!,
      cameraNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}camera_number'],
      )!,
      lightType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}light_type'],
      ),
      lukaCompatible: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}luka_compatible'],
      )!,
      lukaFixtureId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}luka_fixture_id'],
      ),
      externalMappingJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}external_mapping_json'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $CameraPlanElementsTable createAlias(String alias) {
    return $CameraPlanElementsTable(attachedDatabase, alias);
  }
}

class CameraPlanElement extends DataClass
    implements Insertable<CameraPlanElement> {
  final int id;
  final int shotId;
  final String type;
  final double x;
  final double y;
  final double rotation;
  final String? label;
  final String? color;
  final String? cameraStabilization;
  final String? cameraLens;
  final String cameraLetter;
  final int cameraNumber;
  final String? lightType;
  final bool lukaCompatible;
  final String? lukaFixtureId;
  final String? externalMappingJson;
  final int sortOrder;
  const CameraPlanElement({
    required this.id,
    required this.shotId,
    required this.type,
    required this.x,
    required this.y,
    required this.rotation,
    this.label,
    this.color,
    this.cameraStabilization,
    this.cameraLens,
    required this.cameraLetter,
    required this.cameraNumber,
    this.lightType,
    required this.lukaCompatible,
    this.lukaFixtureId,
    this.externalMappingJson,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['shot_id'] = Variable<int>(shotId);
    map['type'] = Variable<String>(type);
    map['x'] = Variable<double>(x);
    map['y'] = Variable<double>(y);
    map['rotation'] = Variable<double>(rotation);
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    if (!nullToAbsent || cameraStabilization != null) {
      map['camera_stabilization'] = Variable<String>(cameraStabilization);
    }
    if (!nullToAbsent || cameraLens != null) {
      map['camera_lens'] = Variable<String>(cameraLens);
    }
    map['camera_letter'] = Variable<String>(cameraLetter);
    map['camera_number'] = Variable<int>(cameraNumber);
    if (!nullToAbsent || lightType != null) {
      map['light_type'] = Variable<String>(lightType);
    }
    map['luka_compatible'] = Variable<bool>(lukaCompatible);
    if (!nullToAbsent || lukaFixtureId != null) {
      map['luka_fixture_id'] = Variable<String>(lukaFixtureId);
    }
    if (!nullToAbsent || externalMappingJson != null) {
      map['external_mapping_json'] = Variable<String>(externalMappingJson);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  CameraPlanElementsCompanion toCompanion(bool nullToAbsent) {
    return CameraPlanElementsCompanion(
      id: Value(id),
      shotId: Value(shotId),
      type: Value(type),
      x: Value(x),
      y: Value(y),
      rotation: Value(rotation),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      cameraStabilization: cameraStabilization == null && nullToAbsent
          ? const Value.absent()
          : Value(cameraStabilization),
      cameraLens: cameraLens == null && nullToAbsent
          ? const Value.absent()
          : Value(cameraLens),
      cameraLetter: Value(cameraLetter),
      cameraNumber: Value(cameraNumber),
      lightType: lightType == null && nullToAbsent
          ? const Value.absent()
          : Value(lightType),
      lukaCompatible: Value(lukaCompatible),
      lukaFixtureId: lukaFixtureId == null && nullToAbsent
          ? const Value.absent()
          : Value(lukaFixtureId),
      externalMappingJson: externalMappingJson == null && nullToAbsent
          ? const Value.absent()
          : Value(externalMappingJson),
      sortOrder: Value(sortOrder),
    );
  }

  factory CameraPlanElement.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CameraPlanElement(
      id: serializer.fromJson<int>(json['id']),
      shotId: serializer.fromJson<int>(json['shotId']),
      type: serializer.fromJson<String>(json['type']),
      x: serializer.fromJson<double>(json['x']),
      y: serializer.fromJson<double>(json['y']),
      rotation: serializer.fromJson<double>(json['rotation']),
      label: serializer.fromJson<String?>(json['label']),
      color: serializer.fromJson<String?>(json['color']),
      cameraStabilization: serializer.fromJson<String?>(
        json['cameraStabilization'],
      ),
      cameraLens: serializer.fromJson<String?>(json['cameraLens']),
      cameraLetter: serializer.fromJson<String>(json['cameraLetter']),
      cameraNumber: serializer.fromJson<int>(json['cameraNumber']),
      lightType: serializer.fromJson<String?>(json['lightType']),
      lukaCompatible: serializer.fromJson<bool>(json['lukaCompatible']),
      lukaFixtureId: serializer.fromJson<String?>(json['lukaFixtureId']),
      externalMappingJson: serializer.fromJson<String?>(
        json['externalMappingJson'],
      ),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'shotId': serializer.toJson<int>(shotId),
      'type': serializer.toJson<String>(type),
      'x': serializer.toJson<double>(x),
      'y': serializer.toJson<double>(y),
      'rotation': serializer.toJson<double>(rotation),
      'label': serializer.toJson<String?>(label),
      'color': serializer.toJson<String?>(color),
      'cameraStabilization': serializer.toJson<String?>(cameraStabilization),
      'cameraLens': serializer.toJson<String?>(cameraLens),
      'cameraLetter': serializer.toJson<String>(cameraLetter),
      'cameraNumber': serializer.toJson<int>(cameraNumber),
      'lightType': serializer.toJson<String?>(lightType),
      'lukaCompatible': serializer.toJson<bool>(lukaCompatible),
      'lukaFixtureId': serializer.toJson<String?>(lukaFixtureId),
      'externalMappingJson': serializer.toJson<String?>(externalMappingJson),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  CameraPlanElement copyWith({
    int? id,
    int? shotId,
    String? type,
    double? x,
    double? y,
    double? rotation,
    Value<String?> label = const Value.absent(),
    Value<String?> color = const Value.absent(),
    Value<String?> cameraStabilization = const Value.absent(),
    Value<String?> cameraLens = const Value.absent(),
    String? cameraLetter,
    int? cameraNumber,
    Value<String?> lightType = const Value.absent(),
    bool? lukaCompatible,
    Value<String?> lukaFixtureId = const Value.absent(),
    Value<String?> externalMappingJson = const Value.absent(),
    int? sortOrder,
  }) => CameraPlanElement(
    id: id ?? this.id,
    shotId: shotId ?? this.shotId,
    type: type ?? this.type,
    x: x ?? this.x,
    y: y ?? this.y,
    rotation: rotation ?? this.rotation,
    label: label.present ? label.value : this.label,
    color: color.present ? color.value : this.color,
    cameraStabilization: cameraStabilization.present
        ? cameraStabilization.value
        : this.cameraStabilization,
    cameraLens: cameraLens.present ? cameraLens.value : this.cameraLens,
    cameraLetter: cameraLetter ?? this.cameraLetter,
    cameraNumber: cameraNumber ?? this.cameraNumber,
    lightType: lightType.present ? lightType.value : this.lightType,
    lukaCompatible: lukaCompatible ?? this.lukaCompatible,
    lukaFixtureId: lukaFixtureId.present
        ? lukaFixtureId.value
        : this.lukaFixtureId,
    externalMappingJson: externalMappingJson.present
        ? externalMappingJson.value
        : this.externalMappingJson,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  CameraPlanElement copyWithCompanion(CameraPlanElementsCompanion data) {
    return CameraPlanElement(
      id: data.id.present ? data.id.value : this.id,
      shotId: data.shotId.present ? data.shotId.value : this.shotId,
      type: data.type.present ? data.type.value : this.type,
      x: data.x.present ? data.x.value : this.x,
      y: data.y.present ? data.y.value : this.y,
      rotation: data.rotation.present ? data.rotation.value : this.rotation,
      label: data.label.present ? data.label.value : this.label,
      color: data.color.present ? data.color.value : this.color,
      cameraStabilization: data.cameraStabilization.present
          ? data.cameraStabilization.value
          : this.cameraStabilization,
      cameraLens: data.cameraLens.present
          ? data.cameraLens.value
          : this.cameraLens,
      cameraLetter: data.cameraLetter.present
          ? data.cameraLetter.value
          : this.cameraLetter,
      cameraNumber: data.cameraNumber.present
          ? data.cameraNumber.value
          : this.cameraNumber,
      lightType: data.lightType.present ? data.lightType.value : this.lightType,
      lukaCompatible: data.lukaCompatible.present
          ? data.lukaCompatible.value
          : this.lukaCompatible,
      lukaFixtureId: data.lukaFixtureId.present
          ? data.lukaFixtureId.value
          : this.lukaFixtureId,
      externalMappingJson: data.externalMappingJson.present
          ? data.externalMappingJson.value
          : this.externalMappingJson,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CameraPlanElement(')
          ..write('id: $id, ')
          ..write('shotId: $shotId, ')
          ..write('type: $type, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('rotation: $rotation, ')
          ..write('label: $label, ')
          ..write('color: $color, ')
          ..write('cameraStabilization: $cameraStabilization, ')
          ..write('cameraLens: $cameraLens, ')
          ..write('cameraLetter: $cameraLetter, ')
          ..write('cameraNumber: $cameraNumber, ')
          ..write('lightType: $lightType, ')
          ..write('lukaCompatible: $lukaCompatible, ')
          ..write('lukaFixtureId: $lukaFixtureId, ')
          ..write('externalMappingJson: $externalMappingJson, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    shotId,
    type,
    x,
    y,
    rotation,
    label,
    color,
    cameraStabilization,
    cameraLens,
    cameraLetter,
    cameraNumber,
    lightType,
    lukaCompatible,
    lukaFixtureId,
    externalMappingJson,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CameraPlanElement &&
          other.id == this.id &&
          other.shotId == this.shotId &&
          other.type == this.type &&
          other.x == this.x &&
          other.y == this.y &&
          other.rotation == this.rotation &&
          other.label == this.label &&
          other.color == this.color &&
          other.cameraStabilization == this.cameraStabilization &&
          other.cameraLens == this.cameraLens &&
          other.cameraLetter == this.cameraLetter &&
          other.cameraNumber == this.cameraNumber &&
          other.lightType == this.lightType &&
          other.lukaCompatible == this.lukaCompatible &&
          other.lukaFixtureId == this.lukaFixtureId &&
          other.externalMappingJson == this.externalMappingJson &&
          other.sortOrder == this.sortOrder);
}

class CameraPlanElementsCompanion extends UpdateCompanion<CameraPlanElement> {
  final Value<int> id;
  final Value<int> shotId;
  final Value<String> type;
  final Value<double> x;
  final Value<double> y;
  final Value<double> rotation;
  final Value<String?> label;
  final Value<String?> color;
  final Value<String?> cameraStabilization;
  final Value<String?> cameraLens;
  final Value<String> cameraLetter;
  final Value<int> cameraNumber;
  final Value<String?> lightType;
  final Value<bool> lukaCompatible;
  final Value<String?> lukaFixtureId;
  final Value<String?> externalMappingJson;
  final Value<int> sortOrder;
  const CameraPlanElementsCompanion({
    this.id = const Value.absent(),
    this.shotId = const Value.absent(),
    this.type = const Value.absent(),
    this.x = const Value.absent(),
    this.y = const Value.absent(),
    this.rotation = const Value.absent(),
    this.label = const Value.absent(),
    this.color = const Value.absent(),
    this.cameraStabilization = const Value.absent(),
    this.cameraLens = const Value.absent(),
    this.cameraLetter = const Value.absent(),
    this.cameraNumber = const Value.absent(),
    this.lightType = const Value.absent(),
    this.lukaCompatible = const Value.absent(),
    this.lukaFixtureId = const Value.absent(),
    this.externalMappingJson = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  CameraPlanElementsCompanion.insert({
    this.id = const Value.absent(),
    required int shotId,
    required String type,
    this.x = const Value.absent(),
    this.y = const Value.absent(),
    this.rotation = const Value.absent(),
    this.label = const Value.absent(),
    this.color = const Value.absent(),
    this.cameraStabilization = const Value.absent(),
    this.cameraLens = const Value.absent(),
    this.cameraLetter = const Value.absent(),
    this.cameraNumber = const Value.absent(),
    this.lightType = const Value.absent(),
    this.lukaCompatible = const Value.absent(),
    this.lukaFixtureId = const Value.absent(),
    this.externalMappingJson = const Value.absent(),
    this.sortOrder = const Value.absent(),
  }) : shotId = Value(shotId),
       type = Value(type);
  static Insertable<CameraPlanElement> custom({
    Expression<int>? id,
    Expression<int>? shotId,
    Expression<String>? type,
    Expression<double>? x,
    Expression<double>? y,
    Expression<double>? rotation,
    Expression<String>? label,
    Expression<String>? color,
    Expression<String>? cameraStabilization,
    Expression<String>? cameraLens,
    Expression<String>? cameraLetter,
    Expression<int>? cameraNumber,
    Expression<String>? lightType,
    Expression<bool>? lukaCompatible,
    Expression<String>? lukaFixtureId,
    Expression<String>? externalMappingJson,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (shotId != null) 'shot_id': shotId,
      if (type != null) 'type': type,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
      if (rotation != null) 'rotation': rotation,
      if (label != null) 'label': label,
      if (color != null) 'color': color,
      if (cameraStabilization != null)
        'camera_stabilization': cameraStabilization,
      if (cameraLens != null) 'camera_lens': cameraLens,
      if (cameraLetter != null) 'camera_letter': cameraLetter,
      if (cameraNumber != null) 'camera_number': cameraNumber,
      if (lightType != null) 'light_type': lightType,
      if (lukaCompatible != null) 'luka_compatible': lukaCompatible,
      if (lukaFixtureId != null) 'luka_fixture_id': lukaFixtureId,
      if (externalMappingJson != null)
        'external_mapping_json': externalMappingJson,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  CameraPlanElementsCompanion copyWith({
    Value<int>? id,
    Value<int>? shotId,
    Value<String>? type,
    Value<double>? x,
    Value<double>? y,
    Value<double>? rotation,
    Value<String?>? label,
    Value<String?>? color,
    Value<String?>? cameraStabilization,
    Value<String?>? cameraLens,
    Value<String>? cameraLetter,
    Value<int>? cameraNumber,
    Value<String?>? lightType,
    Value<bool>? lukaCompatible,
    Value<String?>? lukaFixtureId,
    Value<String?>? externalMappingJson,
    Value<int>? sortOrder,
  }) {
    return CameraPlanElementsCompanion(
      id: id ?? this.id,
      shotId: shotId ?? this.shotId,
      type: type ?? this.type,
      x: x ?? this.x,
      y: y ?? this.y,
      rotation: rotation ?? this.rotation,
      label: label ?? this.label,
      color: color ?? this.color,
      cameraStabilization: cameraStabilization ?? this.cameraStabilization,
      cameraLens: cameraLens ?? this.cameraLens,
      cameraLetter: cameraLetter ?? this.cameraLetter,
      cameraNumber: cameraNumber ?? this.cameraNumber,
      lightType: lightType ?? this.lightType,
      lukaCompatible: lukaCompatible ?? this.lukaCompatible,
      lukaFixtureId: lukaFixtureId ?? this.lukaFixtureId,
      externalMappingJson: externalMappingJson ?? this.externalMappingJson,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (shotId.present) {
      map['shot_id'] = Variable<int>(shotId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (x.present) {
      map['x'] = Variable<double>(x.value);
    }
    if (y.present) {
      map['y'] = Variable<double>(y.value);
    }
    if (rotation.present) {
      map['rotation'] = Variable<double>(rotation.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (cameraStabilization.present) {
      map['camera_stabilization'] = Variable<String>(cameraStabilization.value);
    }
    if (cameraLens.present) {
      map['camera_lens'] = Variable<String>(cameraLens.value);
    }
    if (cameraLetter.present) {
      map['camera_letter'] = Variable<String>(cameraLetter.value);
    }
    if (cameraNumber.present) {
      map['camera_number'] = Variable<int>(cameraNumber.value);
    }
    if (lightType.present) {
      map['light_type'] = Variable<String>(lightType.value);
    }
    if (lukaCompatible.present) {
      map['luka_compatible'] = Variable<bool>(lukaCompatible.value);
    }
    if (lukaFixtureId.present) {
      map['luka_fixture_id'] = Variable<String>(lukaFixtureId.value);
    }
    if (externalMappingJson.present) {
      map['external_mapping_json'] = Variable<String>(
        externalMappingJson.value,
      );
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CameraPlanElementsCompanion(')
          ..write('id: $id, ')
          ..write('shotId: $shotId, ')
          ..write('type: $type, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('rotation: $rotation, ')
          ..write('label: $label, ')
          ..write('color: $color, ')
          ..write('cameraStabilization: $cameraStabilization, ')
          ..write('cameraLens: $cameraLens, ')
          ..write('cameraLetter: $cameraLetter, ')
          ..write('cameraNumber: $cameraNumber, ')
          ..write('lightType: $lightType, ')
          ..write('lukaCompatible: $lukaCompatible, ')
          ..write('lukaFixtureId: $lukaFixtureId, ')
          ..write('externalMappingJson: $externalMappingJson, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }
}

class $CameraPathPointsTable extends CameraPathPoints
    with TableInfo<$CameraPathPointsTable, CameraPathPoint> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CameraPathPointsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _elementIdMeta = const VerificationMeta(
    'elementId',
  );
  @override
  late final GeneratedColumn<int> elementId = GeneratedColumn<int>(
    'element_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES camera_plan_elements (id)',
    ),
  );
  static const VerificationMeta _pointNumberMeta = const VerificationMeta(
    'pointNumber',
  );
  @override
  late final GeneratedColumn<int> pointNumber = GeneratedColumn<int>(
    'point_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _xMeta = const VerificationMeta('x');
  @override
  late final GeneratedColumn<double> x = GeneratedColumn<double>(
    'x',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _yMeta = const VerificationMeta('y');
  @override
  late final GeneratedColumn<double> y = GeneratedColumn<double>(
    'y',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, elementId, pointNumber, x, y];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'camera_path_points';
  @override
  VerificationContext validateIntegrity(
    Insertable<CameraPathPoint> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('element_id')) {
      context.handle(
        _elementIdMeta,
        elementId.isAcceptableOrUnknown(data['element_id']!, _elementIdMeta),
      );
    } else if (isInserting) {
      context.missing(_elementIdMeta);
    }
    if (data.containsKey('point_number')) {
      context.handle(
        _pointNumberMeta,
        pointNumber.isAcceptableOrUnknown(
          data['point_number']!,
          _pointNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_pointNumberMeta);
    }
    if (data.containsKey('x')) {
      context.handle(_xMeta, x.isAcceptableOrUnknown(data['x']!, _xMeta));
    } else if (isInserting) {
      context.missing(_xMeta);
    }
    if (data.containsKey('y')) {
      context.handle(_yMeta, y.isAcceptableOrUnknown(data['y']!, _yMeta));
    } else if (isInserting) {
      context.missing(_yMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CameraPathPoint map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CameraPathPoint(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      elementId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}element_id'],
      )!,
      pointNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}point_number'],
      )!,
      x: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}x'],
      )!,
      y: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}y'],
      )!,
    );
  }

  @override
  $CameraPathPointsTable createAlias(String alias) {
    return $CameraPathPointsTable(attachedDatabase, alias);
  }
}

class CameraPathPoint extends DataClass implements Insertable<CameraPathPoint> {
  final int id;
  final int elementId;
  final int pointNumber;
  final double x;
  final double y;
  const CameraPathPoint({
    required this.id,
    required this.elementId,
    required this.pointNumber,
    required this.x,
    required this.y,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['element_id'] = Variable<int>(elementId);
    map['point_number'] = Variable<int>(pointNumber);
    map['x'] = Variable<double>(x);
    map['y'] = Variable<double>(y);
    return map;
  }

  CameraPathPointsCompanion toCompanion(bool nullToAbsent) {
    return CameraPathPointsCompanion(
      id: Value(id),
      elementId: Value(elementId),
      pointNumber: Value(pointNumber),
      x: Value(x),
      y: Value(y),
    );
  }

  factory CameraPathPoint.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CameraPathPoint(
      id: serializer.fromJson<int>(json['id']),
      elementId: serializer.fromJson<int>(json['elementId']),
      pointNumber: serializer.fromJson<int>(json['pointNumber']),
      x: serializer.fromJson<double>(json['x']),
      y: serializer.fromJson<double>(json['y']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'elementId': serializer.toJson<int>(elementId),
      'pointNumber': serializer.toJson<int>(pointNumber),
      'x': serializer.toJson<double>(x),
      'y': serializer.toJson<double>(y),
    };
  }

  CameraPathPoint copyWith({
    int? id,
    int? elementId,
    int? pointNumber,
    double? x,
    double? y,
  }) => CameraPathPoint(
    id: id ?? this.id,
    elementId: elementId ?? this.elementId,
    pointNumber: pointNumber ?? this.pointNumber,
    x: x ?? this.x,
    y: y ?? this.y,
  );
  CameraPathPoint copyWithCompanion(CameraPathPointsCompanion data) {
    return CameraPathPoint(
      id: data.id.present ? data.id.value : this.id,
      elementId: data.elementId.present ? data.elementId.value : this.elementId,
      pointNumber: data.pointNumber.present
          ? data.pointNumber.value
          : this.pointNumber,
      x: data.x.present ? data.x.value : this.x,
      y: data.y.present ? data.y.value : this.y,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CameraPathPoint(')
          ..write('id: $id, ')
          ..write('elementId: $elementId, ')
          ..write('pointNumber: $pointNumber, ')
          ..write('x: $x, ')
          ..write('y: $y')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, elementId, pointNumber, x, y);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CameraPathPoint &&
          other.id == this.id &&
          other.elementId == this.elementId &&
          other.pointNumber == this.pointNumber &&
          other.x == this.x &&
          other.y == this.y);
}

class CameraPathPointsCompanion extends UpdateCompanion<CameraPathPoint> {
  final Value<int> id;
  final Value<int> elementId;
  final Value<int> pointNumber;
  final Value<double> x;
  final Value<double> y;
  const CameraPathPointsCompanion({
    this.id = const Value.absent(),
    this.elementId = const Value.absent(),
    this.pointNumber = const Value.absent(),
    this.x = const Value.absent(),
    this.y = const Value.absent(),
  });
  CameraPathPointsCompanion.insert({
    this.id = const Value.absent(),
    required int elementId,
    required int pointNumber,
    required double x,
    required double y,
  }) : elementId = Value(elementId),
       pointNumber = Value(pointNumber),
       x = Value(x),
       y = Value(y);
  static Insertable<CameraPathPoint> custom({
    Expression<int>? id,
    Expression<int>? elementId,
    Expression<int>? pointNumber,
    Expression<double>? x,
    Expression<double>? y,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (elementId != null) 'element_id': elementId,
      if (pointNumber != null) 'point_number': pointNumber,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
    });
  }

  CameraPathPointsCompanion copyWith({
    Value<int>? id,
    Value<int>? elementId,
    Value<int>? pointNumber,
    Value<double>? x,
    Value<double>? y,
  }) {
    return CameraPathPointsCompanion(
      id: id ?? this.id,
      elementId: elementId ?? this.elementId,
      pointNumber: pointNumber ?? this.pointNumber,
      x: x ?? this.x,
      y: y ?? this.y,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (elementId.present) {
      map['element_id'] = Variable<int>(elementId.value);
    }
    if (pointNumber.present) {
      map['point_number'] = Variable<int>(pointNumber.value);
    }
    if (x.present) {
      map['x'] = Variable<double>(x.value);
    }
    if (y.present) {
      map['y'] = Variable<double>(y.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CameraPathPointsCompanion(')
          ..write('id: $id, ')
          ..write('elementId: $elementId, ')
          ..write('pointNumber: $pointNumber, ')
          ..write('x: $x, ')
          ..write('y: $y')
          ..write(')'))
        .toString();
  }
}

class $LocationImagesTable extends LocationImages
    with TableInfo<$LocationImagesTable, LocationImage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocationImagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _locationIdMeta = const VerificationMeta(
    'locationId',
  );
  @override
  late final GeneratedColumn<int> locationId = GeneratedColumn<int>(
    'location_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES location_base_plans (id)',
    ),
  );
  static const VerificationMeta _imagePathMeta = const VerificationMeta(
    'imagePath',
  );
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
    'image_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _captionMeta = const VerificationMeta(
    'caption',
  );
  @override
  late final GeneratedColumn<String> caption = GeneratedColumn<String>(
    'caption',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('reference'),
  );
  static const VerificationMeta _timeOfDayMeta = const VerificationMeta(
    'timeOfDay',
  );
  @override
  late final GeneratedColumn<String> timeOfDay = GeneratedColumn<String>(
    'time_of_day',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    locationId,
    imagePath,
    caption,
    kind,
    timeOfDay,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'location_images';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocationImage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('location_id')) {
      context.handle(
        _locationIdMeta,
        locationId.isAcceptableOrUnknown(data['location_id']!, _locationIdMeta),
      );
    } else if (isInserting) {
      context.missing(_locationIdMeta);
    }
    if (data.containsKey('image_path')) {
      context.handle(
        _imagePathMeta,
        imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta),
      );
    } else if (isInserting) {
      context.missing(_imagePathMeta);
    }
    if (data.containsKey('caption')) {
      context.handle(
        _captionMeta,
        caption.isAcceptableOrUnknown(data['caption']!, _captionMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('time_of_day')) {
      context.handle(
        _timeOfDayMeta,
        timeOfDay.isAcceptableOrUnknown(data['time_of_day']!, _timeOfDayMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocationImage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocationImage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      locationId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}location_id'],
      )!,
      imagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_path'],
      )!,
      caption: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}caption'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      timeOfDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_of_day'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $LocationImagesTable createAlias(String alias) {
    return $LocationImagesTable(attachedDatabase, alias);
  }
}

class LocationImage extends DataClass implements Insertable<LocationImage> {
  final int id;
  final int locationId;
  final String imagePath;
  final String? caption;
  final String kind;
  final String? timeOfDay;
  final int sortOrder;
  const LocationImage({
    required this.id,
    required this.locationId,
    required this.imagePath,
    this.caption,
    required this.kind,
    this.timeOfDay,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['location_id'] = Variable<int>(locationId);
    map['image_path'] = Variable<String>(imagePath);
    if (!nullToAbsent || caption != null) {
      map['caption'] = Variable<String>(caption);
    }
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || timeOfDay != null) {
      map['time_of_day'] = Variable<String>(timeOfDay);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  LocationImagesCompanion toCompanion(bool nullToAbsent) {
    return LocationImagesCompanion(
      id: Value(id),
      locationId: Value(locationId),
      imagePath: Value(imagePath),
      caption: caption == null && nullToAbsent
          ? const Value.absent()
          : Value(caption),
      kind: Value(kind),
      timeOfDay: timeOfDay == null && nullToAbsent
          ? const Value.absent()
          : Value(timeOfDay),
      sortOrder: Value(sortOrder),
    );
  }

  factory LocationImage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocationImage(
      id: serializer.fromJson<int>(json['id']),
      locationId: serializer.fromJson<int>(json['locationId']),
      imagePath: serializer.fromJson<String>(json['imagePath']),
      caption: serializer.fromJson<String?>(json['caption']),
      kind: serializer.fromJson<String>(json['kind']),
      timeOfDay: serializer.fromJson<String?>(json['timeOfDay']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'locationId': serializer.toJson<int>(locationId),
      'imagePath': serializer.toJson<String>(imagePath),
      'caption': serializer.toJson<String?>(caption),
      'kind': serializer.toJson<String>(kind),
      'timeOfDay': serializer.toJson<String?>(timeOfDay),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  LocationImage copyWith({
    int? id,
    int? locationId,
    String? imagePath,
    Value<String?> caption = const Value.absent(),
    String? kind,
    Value<String?> timeOfDay = const Value.absent(),
    int? sortOrder,
  }) => LocationImage(
    id: id ?? this.id,
    locationId: locationId ?? this.locationId,
    imagePath: imagePath ?? this.imagePath,
    caption: caption.present ? caption.value : this.caption,
    kind: kind ?? this.kind,
    timeOfDay: timeOfDay.present ? timeOfDay.value : this.timeOfDay,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  LocationImage copyWithCompanion(LocationImagesCompanion data) {
    return LocationImage(
      id: data.id.present ? data.id.value : this.id,
      locationId: data.locationId.present
          ? data.locationId.value
          : this.locationId,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      caption: data.caption.present ? data.caption.value : this.caption,
      kind: data.kind.present ? data.kind.value : this.kind,
      timeOfDay: data.timeOfDay.present ? data.timeOfDay.value : this.timeOfDay,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocationImage(')
          ..write('id: $id, ')
          ..write('locationId: $locationId, ')
          ..write('imagePath: $imagePath, ')
          ..write('caption: $caption, ')
          ..write('kind: $kind, ')
          ..write('timeOfDay: $timeOfDay, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    locationId,
    imagePath,
    caption,
    kind,
    timeOfDay,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocationImage &&
          other.id == this.id &&
          other.locationId == this.locationId &&
          other.imagePath == this.imagePath &&
          other.caption == this.caption &&
          other.kind == this.kind &&
          other.timeOfDay == this.timeOfDay &&
          other.sortOrder == this.sortOrder);
}

class LocationImagesCompanion extends UpdateCompanion<LocationImage> {
  final Value<int> id;
  final Value<int> locationId;
  final Value<String> imagePath;
  final Value<String?> caption;
  final Value<String> kind;
  final Value<String?> timeOfDay;
  final Value<int> sortOrder;
  const LocationImagesCompanion({
    this.id = const Value.absent(),
    this.locationId = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.caption = const Value.absent(),
    this.kind = const Value.absent(),
    this.timeOfDay = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  LocationImagesCompanion.insert({
    this.id = const Value.absent(),
    required int locationId,
    required String imagePath,
    this.caption = const Value.absent(),
    this.kind = const Value.absent(),
    this.timeOfDay = const Value.absent(),
    this.sortOrder = const Value.absent(),
  }) : locationId = Value(locationId),
       imagePath = Value(imagePath);
  static Insertable<LocationImage> custom({
    Expression<int>? id,
    Expression<int>? locationId,
    Expression<String>? imagePath,
    Expression<String>? caption,
    Expression<String>? kind,
    Expression<String>? timeOfDay,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (locationId != null) 'location_id': locationId,
      if (imagePath != null) 'image_path': imagePath,
      if (caption != null) 'caption': caption,
      if (kind != null) 'kind': kind,
      if (timeOfDay != null) 'time_of_day': timeOfDay,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  LocationImagesCompanion copyWith({
    Value<int>? id,
    Value<int>? locationId,
    Value<String>? imagePath,
    Value<String?>? caption,
    Value<String>? kind,
    Value<String?>? timeOfDay,
    Value<int>? sortOrder,
  }) {
    return LocationImagesCompanion(
      id: id ?? this.id,
      locationId: locationId ?? this.locationId,
      imagePath: imagePath ?? this.imagePath,
      caption: caption ?? this.caption,
      kind: kind ?? this.kind,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (locationId.present) {
      map['location_id'] = Variable<int>(locationId.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (caption.present) {
      map['caption'] = Variable<String>(caption.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (timeOfDay.present) {
      map['time_of_day'] = Variable<String>(timeOfDay.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocationImagesCompanion(')
          ..write('id: $id, ')
          ..write('locationId: $locationId, ')
          ..write('imagePath: $imagePath, ')
          ..write('caption: $caption, ')
          ..write('kind: $kind, ')
          ..write('timeOfDay: $timeOfDay, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }
}

class $SiteImagesTable extends SiteImages
    with TableInfo<$SiteImagesTable, SiteImage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SiteImagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _siteIdMeta = const VerificationMeta('siteId');
  @override
  late final GeneratedColumn<int> siteId = GeneratedColumn<int>(
    'site_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES location_sites (id)',
    ),
  );
  static const VerificationMeta _imagePathMeta = const VerificationMeta(
    'imagePath',
  );
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
    'image_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _captionMeta = const VerificationMeta(
    'caption',
  );
  @override
  late final GeneratedColumn<String> caption = GeneratedColumn<String>(
    'caption',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('reference'),
  );
  static const VerificationMeta _timeOfDayMeta = const VerificationMeta(
    'timeOfDay',
  );
  @override
  late final GeneratedColumn<String> timeOfDay = GeneratedColumn<String>(
    'time_of_day',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    siteId,
    imagePath,
    caption,
    kind,
    timeOfDay,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'site_images';
  @override
  VerificationContext validateIntegrity(
    Insertable<SiteImage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('site_id')) {
      context.handle(
        _siteIdMeta,
        siteId.isAcceptableOrUnknown(data['site_id']!, _siteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_siteIdMeta);
    }
    if (data.containsKey('image_path')) {
      context.handle(
        _imagePathMeta,
        imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta),
      );
    } else if (isInserting) {
      context.missing(_imagePathMeta);
    }
    if (data.containsKey('caption')) {
      context.handle(
        _captionMeta,
        caption.isAcceptableOrUnknown(data['caption']!, _captionMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('time_of_day')) {
      context.handle(
        _timeOfDayMeta,
        timeOfDay.isAcceptableOrUnknown(data['time_of_day']!, _timeOfDayMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SiteImage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SiteImage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      siteId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}site_id'],
      )!,
      imagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_path'],
      )!,
      caption: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}caption'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      timeOfDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_of_day'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $SiteImagesTable createAlias(String alias) {
    return $SiteImagesTable(attachedDatabase, alias);
  }
}

class SiteImage extends DataClass implements Insertable<SiteImage> {
  final int id;
  final int siteId;
  final String imagePath;
  final String? caption;
  final String kind;
  final String? timeOfDay;
  final int sortOrder;
  const SiteImage({
    required this.id,
    required this.siteId,
    required this.imagePath,
    this.caption,
    required this.kind,
    this.timeOfDay,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['site_id'] = Variable<int>(siteId);
    map['image_path'] = Variable<String>(imagePath);
    if (!nullToAbsent || caption != null) {
      map['caption'] = Variable<String>(caption);
    }
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || timeOfDay != null) {
      map['time_of_day'] = Variable<String>(timeOfDay);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  SiteImagesCompanion toCompanion(bool nullToAbsent) {
    return SiteImagesCompanion(
      id: Value(id),
      siteId: Value(siteId),
      imagePath: Value(imagePath),
      caption: caption == null && nullToAbsent
          ? const Value.absent()
          : Value(caption),
      kind: Value(kind),
      timeOfDay: timeOfDay == null && nullToAbsent
          ? const Value.absent()
          : Value(timeOfDay),
      sortOrder: Value(sortOrder),
    );
  }

  factory SiteImage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SiteImage(
      id: serializer.fromJson<int>(json['id']),
      siteId: serializer.fromJson<int>(json['siteId']),
      imagePath: serializer.fromJson<String>(json['imagePath']),
      caption: serializer.fromJson<String?>(json['caption']),
      kind: serializer.fromJson<String>(json['kind']),
      timeOfDay: serializer.fromJson<String?>(json['timeOfDay']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'siteId': serializer.toJson<int>(siteId),
      'imagePath': serializer.toJson<String>(imagePath),
      'caption': serializer.toJson<String?>(caption),
      'kind': serializer.toJson<String>(kind),
      'timeOfDay': serializer.toJson<String?>(timeOfDay),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  SiteImage copyWith({
    int? id,
    int? siteId,
    String? imagePath,
    Value<String?> caption = const Value.absent(),
    String? kind,
    Value<String?> timeOfDay = const Value.absent(),
    int? sortOrder,
  }) => SiteImage(
    id: id ?? this.id,
    siteId: siteId ?? this.siteId,
    imagePath: imagePath ?? this.imagePath,
    caption: caption.present ? caption.value : this.caption,
    kind: kind ?? this.kind,
    timeOfDay: timeOfDay.present ? timeOfDay.value : this.timeOfDay,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  SiteImage copyWithCompanion(SiteImagesCompanion data) {
    return SiteImage(
      id: data.id.present ? data.id.value : this.id,
      siteId: data.siteId.present ? data.siteId.value : this.siteId,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      caption: data.caption.present ? data.caption.value : this.caption,
      kind: data.kind.present ? data.kind.value : this.kind,
      timeOfDay: data.timeOfDay.present ? data.timeOfDay.value : this.timeOfDay,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SiteImage(')
          ..write('id: $id, ')
          ..write('siteId: $siteId, ')
          ..write('imagePath: $imagePath, ')
          ..write('caption: $caption, ')
          ..write('kind: $kind, ')
          ..write('timeOfDay: $timeOfDay, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, siteId, imagePath, caption, kind, timeOfDay, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SiteImage &&
          other.id == this.id &&
          other.siteId == this.siteId &&
          other.imagePath == this.imagePath &&
          other.caption == this.caption &&
          other.kind == this.kind &&
          other.timeOfDay == this.timeOfDay &&
          other.sortOrder == this.sortOrder);
}

class SiteImagesCompanion extends UpdateCompanion<SiteImage> {
  final Value<int> id;
  final Value<int> siteId;
  final Value<String> imagePath;
  final Value<String?> caption;
  final Value<String> kind;
  final Value<String?> timeOfDay;
  final Value<int> sortOrder;
  const SiteImagesCompanion({
    this.id = const Value.absent(),
    this.siteId = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.caption = const Value.absent(),
    this.kind = const Value.absent(),
    this.timeOfDay = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  SiteImagesCompanion.insert({
    this.id = const Value.absent(),
    required int siteId,
    required String imagePath,
    this.caption = const Value.absent(),
    this.kind = const Value.absent(),
    this.timeOfDay = const Value.absent(),
    this.sortOrder = const Value.absent(),
  }) : siteId = Value(siteId),
       imagePath = Value(imagePath);
  static Insertable<SiteImage> custom({
    Expression<int>? id,
    Expression<int>? siteId,
    Expression<String>? imagePath,
    Expression<String>? caption,
    Expression<String>? kind,
    Expression<String>? timeOfDay,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (siteId != null) 'site_id': siteId,
      if (imagePath != null) 'image_path': imagePath,
      if (caption != null) 'caption': caption,
      if (kind != null) 'kind': kind,
      if (timeOfDay != null) 'time_of_day': timeOfDay,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  SiteImagesCompanion copyWith({
    Value<int>? id,
    Value<int>? siteId,
    Value<String>? imagePath,
    Value<String?>? caption,
    Value<String>? kind,
    Value<String?>? timeOfDay,
    Value<int>? sortOrder,
  }) {
    return SiteImagesCompanion(
      id: id ?? this.id,
      siteId: siteId ?? this.siteId,
      imagePath: imagePath ?? this.imagePath,
      caption: caption ?? this.caption,
      kind: kind ?? this.kind,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (siteId.present) {
      map['site_id'] = Variable<int>(siteId.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (caption.present) {
      map['caption'] = Variable<String>(caption.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (timeOfDay.present) {
      map['time_of_day'] = Variable<String>(timeOfDay.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SiteImagesCompanion(')
          ..write('id: $id, ')
          ..write('siteId: $siteId, ')
          ..write('imagePath: $imagePath, ')
          ..write('caption: $caption, ')
          ..write('kind: $kind, ')
          ..write('timeOfDay: $timeOfDay, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }
}

class $CamerasTable extends Cameras with TableInfo<$CamerasTable, Camera> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CamerasTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _brandMeta = const VerificationMeta('brand');
  @override
  late final GeneratedColumn<String> brand = GeneratedColumn<String>(
    'brand',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sensorWidthMmMeta = const VerificationMeta(
    'sensorWidthMm',
  );
  @override
  late final GeneratedColumn<double> sensorWidthMm = GeneratedColumn<double>(
    'sensor_width_mm',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sensorHeightMmMeta = const VerificationMeta(
    'sensorHeightMm',
  );
  @override
  late final GeneratedColumn<double> sensorHeightMm = GeneratedColumn<double>(
    'sensor_height_mm',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordingFormatsMeta = const VerificationMeta(
    'recordingFormats',
  );
  @override
  late final GeneratedColumn<String> recordingFormats = GeneratedColumn<String>(
    'recording_formats',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    brand,
    model,
    sensorWidthMm,
    sensorHeightMm,
    recordingFormats,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cameras';
  @override
  VerificationContext validateIntegrity(
    Insertable<Camera> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('brand')) {
      context.handle(
        _brandMeta,
        brand.isAcceptableOrUnknown(data['brand']!, _brandMeta),
      );
    } else if (isInserting) {
      context.missing(_brandMeta);
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('sensor_width_mm')) {
      context.handle(
        _sensorWidthMmMeta,
        sensorWidthMm.isAcceptableOrUnknown(
          data['sensor_width_mm']!,
          _sensorWidthMmMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sensorWidthMmMeta);
    }
    if (data.containsKey('sensor_height_mm')) {
      context.handle(
        _sensorHeightMmMeta,
        sensorHeightMm.isAcceptableOrUnknown(
          data['sensor_height_mm']!,
          _sensorHeightMmMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sensorHeightMmMeta);
    }
    if (data.containsKey('recording_formats')) {
      context.handle(
        _recordingFormatsMeta,
        recordingFormats.isAcceptableOrUnknown(
          data['recording_formats']!,
          _recordingFormatsMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Camera map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Camera(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      brand: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}brand'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      )!,
      sensorWidthMm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sensor_width_mm'],
      )!,
      sensorHeightMm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sensor_height_mm'],
      )!,
      recordingFormats: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recording_formats'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $CamerasTable createAlias(String alias) {
    return $CamerasTable(attachedDatabase, alias);
  }
}

class Camera extends DataClass implements Insertable<Camera> {
  final int id;
  final String brand;
  final String model;
  final double sensorWidthMm;
  final double sensorHeightMm;
  final String? recordingFormats;
  final String? notes;
  const Camera({
    required this.id,
    required this.brand,
    required this.model,
    required this.sensorWidthMm,
    required this.sensorHeightMm,
    this.recordingFormats,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['brand'] = Variable<String>(brand);
    map['model'] = Variable<String>(model);
    map['sensor_width_mm'] = Variable<double>(sensorWidthMm);
    map['sensor_height_mm'] = Variable<double>(sensorHeightMm);
    if (!nullToAbsent || recordingFormats != null) {
      map['recording_formats'] = Variable<String>(recordingFormats);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  CamerasCompanion toCompanion(bool nullToAbsent) {
    return CamerasCompanion(
      id: Value(id),
      brand: Value(brand),
      model: Value(model),
      sensorWidthMm: Value(sensorWidthMm),
      sensorHeightMm: Value(sensorHeightMm),
      recordingFormats: recordingFormats == null && nullToAbsent
          ? const Value.absent()
          : Value(recordingFormats),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory Camera.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Camera(
      id: serializer.fromJson<int>(json['id']),
      brand: serializer.fromJson<String>(json['brand']),
      model: serializer.fromJson<String>(json['model']),
      sensorWidthMm: serializer.fromJson<double>(json['sensorWidthMm']),
      sensorHeightMm: serializer.fromJson<double>(json['sensorHeightMm']),
      recordingFormats: serializer.fromJson<String?>(json['recordingFormats']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'brand': serializer.toJson<String>(brand),
      'model': serializer.toJson<String>(model),
      'sensorWidthMm': serializer.toJson<double>(sensorWidthMm),
      'sensorHeightMm': serializer.toJson<double>(sensorHeightMm),
      'recordingFormats': serializer.toJson<String?>(recordingFormats),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  Camera copyWith({
    int? id,
    String? brand,
    String? model,
    double? sensorWidthMm,
    double? sensorHeightMm,
    Value<String?> recordingFormats = const Value.absent(),
    Value<String?> notes = const Value.absent(),
  }) => Camera(
    id: id ?? this.id,
    brand: brand ?? this.brand,
    model: model ?? this.model,
    sensorWidthMm: sensorWidthMm ?? this.sensorWidthMm,
    sensorHeightMm: sensorHeightMm ?? this.sensorHeightMm,
    recordingFormats: recordingFormats.present
        ? recordingFormats.value
        : this.recordingFormats,
    notes: notes.present ? notes.value : this.notes,
  );
  Camera copyWithCompanion(CamerasCompanion data) {
    return Camera(
      id: data.id.present ? data.id.value : this.id,
      brand: data.brand.present ? data.brand.value : this.brand,
      model: data.model.present ? data.model.value : this.model,
      sensorWidthMm: data.sensorWidthMm.present
          ? data.sensorWidthMm.value
          : this.sensorWidthMm,
      sensorHeightMm: data.sensorHeightMm.present
          ? data.sensorHeightMm.value
          : this.sensorHeightMm,
      recordingFormats: data.recordingFormats.present
          ? data.recordingFormats.value
          : this.recordingFormats,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Camera(')
          ..write('id: $id, ')
          ..write('brand: $brand, ')
          ..write('model: $model, ')
          ..write('sensorWidthMm: $sensorWidthMm, ')
          ..write('sensorHeightMm: $sensorHeightMm, ')
          ..write('recordingFormats: $recordingFormats, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    brand,
    model,
    sensorWidthMm,
    sensorHeightMm,
    recordingFormats,
    notes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Camera &&
          other.id == this.id &&
          other.brand == this.brand &&
          other.model == this.model &&
          other.sensorWidthMm == this.sensorWidthMm &&
          other.sensorHeightMm == this.sensorHeightMm &&
          other.recordingFormats == this.recordingFormats &&
          other.notes == this.notes);
}

class CamerasCompanion extends UpdateCompanion<Camera> {
  final Value<int> id;
  final Value<String> brand;
  final Value<String> model;
  final Value<double> sensorWidthMm;
  final Value<double> sensorHeightMm;
  final Value<String?> recordingFormats;
  final Value<String?> notes;
  const CamerasCompanion({
    this.id = const Value.absent(),
    this.brand = const Value.absent(),
    this.model = const Value.absent(),
    this.sensorWidthMm = const Value.absent(),
    this.sensorHeightMm = const Value.absent(),
    this.recordingFormats = const Value.absent(),
    this.notes = const Value.absent(),
  });
  CamerasCompanion.insert({
    this.id = const Value.absent(),
    required String brand,
    required String model,
    required double sensorWidthMm,
    required double sensorHeightMm,
    this.recordingFormats = const Value.absent(),
    this.notes = const Value.absent(),
  }) : brand = Value(brand),
       model = Value(model),
       sensorWidthMm = Value(sensorWidthMm),
       sensorHeightMm = Value(sensorHeightMm);
  static Insertable<Camera> custom({
    Expression<int>? id,
    Expression<String>? brand,
    Expression<String>? model,
    Expression<double>? sensorWidthMm,
    Expression<double>? sensorHeightMm,
    Expression<String>? recordingFormats,
    Expression<String>? notes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (brand != null) 'brand': brand,
      if (model != null) 'model': model,
      if (sensorWidthMm != null) 'sensor_width_mm': sensorWidthMm,
      if (sensorHeightMm != null) 'sensor_height_mm': sensorHeightMm,
      if (recordingFormats != null) 'recording_formats': recordingFormats,
      if (notes != null) 'notes': notes,
    });
  }

  CamerasCompanion copyWith({
    Value<int>? id,
    Value<String>? brand,
    Value<String>? model,
    Value<double>? sensorWidthMm,
    Value<double>? sensorHeightMm,
    Value<String?>? recordingFormats,
    Value<String?>? notes,
  }) {
    return CamerasCompanion(
      id: id ?? this.id,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      sensorWidthMm: sensorWidthMm ?? this.sensorWidthMm,
      sensorHeightMm: sensorHeightMm ?? this.sensorHeightMm,
      recordingFormats: recordingFormats ?? this.recordingFormats,
      notes: notes ?? this.notes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (brand.present) {
      map['brand'] = Variable<String>(brand.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (sensorWidthMm.present) {
      map['sensor_width_mm'] = Variable<double>(sensorWidthMm.value);
    }
    if (sensorHeightMm.present) {
      map['sensor_height_mm'] = Variable<double>(sensorHeightMm.value);
    }
    if (recordingFormats.present) {
      map['recording_formats'] = Variable<String>(recordingFormats.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CamerasCompanion(')
          ..write('id: $id, ')
          ..write('brand: $brand, ')
          ..write('model: $model, ')
          ..write('sensorWidthMm: $sensorWidthMm, ')
          ..write('sensorHeightMm: $sensorHeightMm, ')
          ..write('recordingFormats: $recordingFormats, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

class $LensesTable extends Lenses with TableInfo<$LensesTable, Lense> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LensesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _brandMeta = const VerificationMeta('brand');
  @override
  late final GeneratedColumn<String> brand = GeneratedColumn<String>(
    'brand',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _focalLengthMeta = const VerificationMeta(
    'focalLength',
  );
  @override
  late final GeneratedColumn<double> focalLength = GeneratedColumn<double>(
    'focal_length',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _focalMinMeta = const VerificationMeta(
    'focalMin',
  );
  @override
  late final GeneratedColumn<double> focalMin = GeneratedColumn<double>(
    'focal_min',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _focalMaxMeta = const VerificationMeta(
    'focalMax',
  );
  @override
  late final GeneratedColumn<double> focalMax = GeneratedColumn<double>(
    'focal_max',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _minTStopMeta = const VerificationMeta(
    'minTStop',
  );
  @override
  late final GeneratedColumn<double> minTStop = GeneratedColumn<double>(
    'min_t_stop',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formatCoverageMeta = const VerificationMeta(
    'formatCoverage',
  );
  @override
  late final GeneratedColumn<String> formatCoverage = GeneratedColumn<String>(
    'format_coverage',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    brand,
    model,
    focalLength,
    focalMin,
    focalMax,
    minTStop,
    formatCoverage,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lenses';
  @override
  VerificationContext validateIntegrity(
    Insertable<Lense> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('brand')) {
      context.handle(
        _brandMeta,
        brand.isAcceptableOrUnknown(data['brand']!, _brandMeta),
      );
    } else if (isInserting) {
      context.missing(_brandMeta);
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('focal_length')) {
      context.handle(
        _focalLengthMeta,
        focalLength.isAcceptableOrUnknown(
          data['focal_length']!,
          _focalLengthMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_focalLengthMeta);
    }
    if (data.containsKey('focal_min')) {
      context.handle(
        _focalMinMeta,
        focalMin.isAcceptableOrUnknown(data['focal_min']!, _focalMinMeta),
      );
    }
    if (data.containsKey('focal_max')) {
      context.handle(
        _focalMaxMeta,
        focalMax.isAcceptableOrUnknown(data['focal_max']!, _focalMaxMeta),
      );
    }
    if (data.containsKey('min_t_stop')) {
      context.handle(
        _minTStopMeta,
        minTStop.isAcceptableOrUnknown(data['min_t_stop']!, _minTStopMeta),
      );
    } else if (isInserting) {
      context.missing(_minTStopMeta);
    }
    if (data.containsKey('format_coverage')) {
      context.handle(
        _formatCoverageMeta,
        formatCoverage.isAcceptableOrUnknown(
          data['format_coverage']!,
          _formatCoverageMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_formatCoverageMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Lense map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Lense(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      brand: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}brand'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      )!,
      focalLength: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}focal_length'],
      )!,
      focalMin: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}focal_min'],
      ),
      focalMax: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}focal_max'],
      ),
      minTStop: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}min_t_stop'],
      )!,
      formatCoverage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format_coverage'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $LensesTable createAlias(String alias) {
    return $LensesTable(attachedDatabase, alias);
  }
}

class Lense extends DataClass implements Insertable<Lense> {
  final int id;
  final String brand;
  final String model;
  final double focalLength;
  final double? focalMin;
  final double? focalMax;
  final double minTStop;
  final String formatCoverage;
  final String? notes;
  const Lense({
    required this.id,
    required this.brand,
    required this.model,
    required this.focalLength,
    this.focalMin,
    this.focalMax,
    required this.minTStop,
    required this.formatCoverage,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['brand'] = Variable<String>(brand);
    map['model'] = Variable<String>(model);
    map['focal_length'] = Variable<double>(focalLength);
    if (!nullToAbsent || focalMin != null) {
      map['focal_min'] = Variable<double>(focalMin);
    }
    if (!nullToAbsent || focalMax != null) {
      map['focal_max'] = Variable<double>(focalMax);
    }
    map['min_t_stop'] = Variable<double>(minTStop);
    map['format_coverage'] = Variable<String>(formatCoverage);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  LensesCompanion toCompanion(bool nullToAbsent) {
    return LensesCompanion(
      id: Value(id),
      brand: Value(brand),
      model: Value(model),
      focalLength: Value(focalLength),
      focalMin: focalMin == null && nullToAbsent
          ? const Value.absent()
          : Value(focalMin),
      focalMax: focalMax == null && nullToAbsent
          ? const Value.absent()
          : Value(focalMax),
      minTStop: Value(minTStop),
      formatCoverage: Value(formatCoverage),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory Lense.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Lense(
      id: serializer.fromJson<int>(json['id']),
      brand: serializer.fromJson<String>(json['brand']),
      model: serializer.fromJson<String>(json['model']),
      focalLength: serializer.fromJson<double>(json['focalLength']),
      focalMin: serializer.fromJson<double?>(json['focalMin']),
      focalMax: serializer.fromJson<double?>(json['focalMax']),
      minTStop: serializer.fromJson<double>(json['minTStop']),
      formatCoverage: serializer.fromJson<String>(json['formatCoverage']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'brand': serializer.toJson<String>(brand),
      'model': serializer.toJson<String>(model),
      'focalLength': serializer.toJson<double>(focalLength),
      'focalMin': serializer.toJson<double?>(focalMin),
      'focalMax': serializer.toJson<double?>(focalMax),
      'minTStop': serializer.toJson<double>(minTStop),
      'formatCoverage': serializer.toJson<String>(formatCoverage),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  Lense copyWith({
    int? id,
    String? brand,
    String? model,
    double? focalLength,
    Value<double?> focalMin = const Value.absent(),
    Value<double?> focalMax = const Value.absent(),
    double? minTStop,
    String? formatCoverage,
    Value<String?> notes = const Value.absent(),
  }) => Lense(
    id: id ?? this.id,
    brand: brand ?? this.brand,
    model: model ?? this.model,
    focalLength: focalLength ?? this.focalLength,
    focalMin: focalMin.present ? focalMin.value : this.focalMin,
    focalMax: focalMax.present ? focalMax.value : this.focalMax,
    minTStop: minTStop ?? this.minTStop,
    formatCoverage: formatCoverage ?? this.formatCoverage,
    notes: notes.present ? notes.value : this.notes,
  );
  Lense copyWithCompanion(LensesCompanion data) {
    return Lense(
      id: data.id.present ? data.id.value : this.id,
      brand: data.brand.present ? data.brand.value : this.brand,
      model: data.model.present ? data.model.value : this.model,
      focalLength: data.focalLength.present
          ? data.focalLength.value
          : this.focalLength,
      focalMin: data.focalMin.present ? data.focalMin.value : this.focalMin,
      focalMax: data.focalMax.present ? data.focalMax.value : this.focalMax,
      minTStop: data.minTStop.present ? data.minTStop.value : this.minTStop,
      formatCoverage: data.formatCoverage.present
          ? data.formatCoverage.value
          : this.formatCoverage,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Lense(')
          ..write('id: $id, ')
          ..write('brand: $brand, ')
          ..write('model: $model, ')
          ..write('focalLength: $focalLength, ')
          ..write('focalMin: $focalMin, ')
          ..write('focalMax: $focalMax, ')
          ..write('minTStop: $minTStop, ')
          ..write('formatCoverage: $formatCoverage, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    brand,
    model,
    focalLength,
    focalMin,
    focalMax,
    minTStop,
    formatCoverage,
    notes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Lense &&
          other.id == this.id &&
          other.brand == this.brand &&
          other.model == this.model &&
          other.focalLength == this.focalLength &&
          other.focalMin == this.focalMin &&
          other.focalMax == this.focalMax &&
          other.minTStop == this.minTStop &&
          other.formatCoverage == this.formatCoverage &&
          other.notes == this.notes);
}

class LensesCompanion extends UpdateCompanion<Lense> {
  final Value<int> id;
  final Value<String> brand;
  final Value<String> model;
  final Value<double> focalLength;
  final Value<double?> focalMin;
  final Value<double?> focalMax;
  final Value<double> minTStop;
  final Value<String> formatCoverage;
  final Value<String?> notes;
  const LensesCompanion({
    this.id = const Value.absent(),
    this.brand = const Value.absent(),
    this.model = const Value.absent(),
    this.focalLength = const Value.absent(),
    this.focalMin = const Value.absent(),
    this.focalMax = const Value.absent(),
    this.minTStop = const Value.absent(),
    this.formatCoverage = const Value.absent(),
    this.notes = const Value.absent(),
  });
  LensesCompanion.insert({
    this.id = const Value.absent(),
    required String brand,
    required String model,
    required double focalLength,
    this.focalMin = const Value.absent(),
    this.focalMax = const Value.absent(),
    required double minTStop,
    required String formatCoverage,
    this.notes = const Value.absent(),
  }) : brand = Value(brand),
       model = Value(model),
       focalLength = Value(focalLength),
       minTStop = Value(minTStop),
       formatCoverage = Value(formatCoverage);
  static Insertable<Lense> custom({
    Expression<int>? id,
    Expression<String>? brand,
    Expression<String>? model,
    Expression<double>? focalLength,
    Expression<double>? focalMin,
    Expression<double>? focalMax,
    Expression<double>? minTStop,
    Expression<String>? formatCoverage,
    Expression<String>? notes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (brand != null) 'brand': brand,
      if (model != null) 'model': model,
      if (focalLength != null) 'focal_length': focalLength,
      if (focalMin != null) 'focal_min': focalMin,
      if (focalMax != null) 'focal_max': focalMax,
      if (minTStop != null) 'min_t_stop': minTStop,
      if (formatCoverage != null) 'format_coverage': formatCoverage,
      if (notes != null) 'notes': notes,
    });
  }

  LensesCompanion copyWith({
    Value<int>? id,
    Value<String>? brand,
    Value<String>? model,
    Value<double>? focalLength,
    Value<double?>? focalMin,
    Value<double?>? focalMax,
    Value<double>? minTStop,
    Value<String>? formatCoverage,
    Value<String?>? notes,
  }) {
    return LensesCompanion(
      id: id ?? this.id,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      focalLength: focalLength ?? this.focalLength,
      focalMin: focalMin ?? this.focalMin,
      focalMax: focalMax ?? this.focalMax,
      minTStop: minTStop ?? this.minTStop,
      formatCoverage: formatCoverage ?? this.formatCoverage,
      notes: notes ?? this.notes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (brand.present) {
      map['brand'] = Variable<String>(brand.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (focalLength.present) {
      map['focal_length'] = Variable<double>(focalLength.value);
    }
    if (focalMin.present) {
      map['focal_min'] = Variable<double>(focalMin.value);
    }
    if (focalMax.present) {
      map['focal_max'] = Variable<double>(focalMax.value);
    }
    if (minTStop.present) {
      map['min_t_stop'] = Variable<double>(minTStop.value);
    }
    if (formatCoverage.present) {
      map['format_coverage'] = Variable<String>(formatCoverage.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LensesCompanion(')
          ..write('id: $id, ')
          ..write('brand: $brand, ')
          ..write('model: $model, ')
          ..write('focalLength: $focalLength, ')
          ..write('focalMin: $focalMin, ')
          ..write('focalMax: $focalMax, ')
          ..write('minTStop: $minTStop, ')
          ..write('formatCoverage: $formatCoverage, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

class $LightsTable extends Lights with TableInfo<$LightsTable, Light> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LightsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _brandMeta = const VerificationMeta('brand');
  @override
  late final GeneratedColumn<String> brand = GeneratedColumn<String>(
    'brand',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lightTypeMeta = const VerificationMeta(
    'lightType',
  );
  @override
  late final GeneratedColumn<String> lightType = GeneratedColumn<String>(
    'light_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _powerWMeta = const VerificationMeta('powerW');
  @override
  late final GeneratedColumn<int> powerW = GeneratedColumn<int>(
    'power_w',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorTempMinMeta = const VerificationMeta(
    'colorTempMin',
  );
  @override
  late final GeneratedColumn<int> colorTempMin = GeneratedColumn<int>(
    'color_temp_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorTempMaxMeta = const VerificationMeta(
    'colorTempMax',
  );
  @override
  late final GeneratedColumn<int> colorTempMax = GeneratedColumn<int>(
    'color_temp_max',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isLukaCompatibleMeta = const VerificationMeta(
    'isLukaCompatible',
  );
  @override
  late final GeneratedColumn<bool> isLukaCompatible = GeneratedColumn<bool>(
    'is_luka_compatible',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_luka_compatible" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lukaFixtureIdMeta = const VerificationMeta(
    'lukaFixtureId',
  );
  @override
  late final GeneratedColumn<String> lukaFixtureId = GeneratedColumn<String>(
    'luka_fixture_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    brand,
    model,
    lightType,
    powerW,
    colorTempMin,
    colorTempMax,
    isLukaCompatible,
    lukaFixtureId,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lights';
  @override
  VerificationContext validateIntegrity(
    Insertable<Light> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('brand')) {
      context.handle(
        _brandMeta,
        brand.isAcceptableOrUnknown(data['brand']!, _brandMeta),
      );
    } else if (isInserting) {
      context.missing(_brandMeta);
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('light_type')) {
      context.handle(
        _lightTypeMeta,
        lightType.isAcceptableOrUnknown(data['light_type']!, _lightTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_lightTypeMeta);
    }
    if (data.containsKey('power_w')) {
      context.handle(
        _powerWMeta,
        powerW.isAcceptableOrUnknown(data['power_w']!, _powerWMeta),
      );
    } else if (isInserting) {
      context.missing(_powerWMeta);
    }
    if (data.containsKey('color_temp_min')) {
      context.handle(
        _colorTempMinMeta,
        colorTempMin.isAcceptableOrUnknown(
          data['color_temp_min']!,
          _colorTempMinMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_colorTempMinMeta);
    }
    if (data.containsKey('color_temp_max')) {
      context.handle(
        _colorTempMaxMeta,
        colorTempMax.isAcceptableOrUnknown(
          data['color_temp_max']!,
          _colorTempMaxMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_colorTempMaxMeta);
    }
    if (data.containsKey('is_luka_compatible')) {
      context.handle(
        _isLukaCompatibleMeta,
        isLukaCompatible.isAcceptableOrUnknown(
          data['is_luka_compatible']!,
          _isLukaCompatibleMeta,
        ),
      );
    }
    if (data.containsKey('luka_fixture_id')) {
      context.handle(
        _lukaFixtureIdMeta,
        lukaFixtureId.isAcceptableOrUnknown(
          data['luka_fixture_id']!,
          _lukaFixtureIdMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Light map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Light(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      brand: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}brand'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      )!,
      lightType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}light_type'],
      )!,
      powerW: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}power_w'],
      )!,
      colorTempMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_temp_min'],
      )!,
      colorTempMax: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_temp_max'],
      )!,
      isLukaCompatible: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_luka_compatible'],
      )!,
      lukaFixtureId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}luka_fixture_id'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $LightsTable createAlias(String alias) {
    return $LightsTable(attachedDatabase, alias);
  }
}

class Light extends DataClass implements Insertable<Light> {
  final int id;
  final String brand;
  final String model;
  final String lightType;
  final int powerW;
  final int colorTempMin;
  final int colorTempMax;
  final bool isLukaCompatible;
  final String? lukaFixtureId;
  final String? notes;
  const Light({
    required this.id,
    required this.brand,
    required this.model,
    required this.lightType,
    required this.powerW,
    required this.colorTempMin,
    required this.colorTempMax,
    required this.isLukaCompatible,
    this.lukaFixtureId,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['brand'] = Variable<String>(brand);
    map['model'] = Variable<String>(model);
    map['light_type'] = Variable<String>(lightType);
    map['power_w'] = Variable<int>(powerW);
    map['color_temp_min'] = Variable<int>(colorTempMin);
    map['color_temp_max'] = Variable<int>(colorTempMax);
    map['is_luka_compatible'] = Variable<bool>(isLukaCompatible);
    if (!nullToAbsent || lukaFixtureId != null) {
      map['luka_fixture_id'] = Variable<String>(lukaFixtureId);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  LightsCompanion toCompanion(bool nullToAbsent) {
    return LightsCompanion(
      id: Value(id),
      brand: Value(brand),
      model: Value(model),
      lightType: Value(lightType),
      powerW: Value(powerW),
      colorTempMin: Value(colorTempMin),
      colorTempMax: Value(colorTempMax),
      isLukaCompatible: Value(isLukaCompatible),
      lukaFixtureId: lukaFixtureId == null && nullToAbsent
          ? const Value.absent()
          : Value(lukaFixtureId),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory Light.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Light(
      id: serializer.fromJson<int>(json['id']),
      brand: serializer.fromJson<String>(json['brand']),
      model: serializer.fromJson<String>(json['model']),
      lightType: serializer.fromJson<String>(json['lightType']),
      powerW: serializer.fromJson<int>(json['powerW']),
      colorTempMin: serializer.fromJson<int>(json['colorTempMin']),
      colorTempMax: serializer.fromJson<int>(json['colorTempMax']),
      isLukaCompatible: serializer.fromJson<bool>(json['isLukaCompatible']),
      lukaFixtureId: serializer.fromJson<String?>(json['lukaFixtureId']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'brand': serializer.toJson<String>(brand),
      'model': serializer.toJson<String>(model),
      'lightType': serializer.toJson<String>(lightType),
      'powerW': serializer.toJson<int>(powerW),
      'colorTempMin': serializer.toJson<int>(colorTempMin),
      'colorTempMax': serializer.toJson<int>(colorTempMax),
      'isLukaCompatible': serializer.toJson<bool>(isLukaCompatible),
      'lukaFixtureId': serializer.toJson<String?>(lukaFixtureId),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  Light copyWith({
    int? id,
    String? brand,
    String? model,
    String? lightType,
    int? powerW,
    int? colorTempMin,
    int? colorTempMax,
    bool? isLukaCompatible,
    Value<String?> lukaFixtureId = const Value.absent(),
    Value<String?> notes = const Value.absent(),
  }) => Light(
    id: id ?? this.id,
    brand: brand ?? this.brand,
    model: model ?? this.model,
    lightType: lightType ?? this.lightType,
    powerW: powerW ?? this.powerW,
    colorTempMin: colorTempMin ?? this.colorTempMin,
    colorTempMax: colorTempMax ?? this.colorTempMax,
    isLukaCompatible: isLukaCompatible ?? this.isLukaCompatible,
    lukaFixtureId: lukaFixtureId.present
        ? lukaFixtureId.value
        : this.lukaFixtureId,
    notes: notes.present ? notes.value : this.notes,
  );
  Light copyWithCompanion(LightsCompanion data) {
    return Light(
      id: data.id.present ? data.id.value : this.id,
      brand: data.brand.present ? data.brand.value : this.brand,
      model: data.model.present ? data.model.value : this.model,
      lightType: data.lightType.present ? data.lightType.value : this.lightType,
      powerW: data.powerW.present ? data.powerW.value : this.powerW,
      colorTempMin: data.colorTempMin.present
          ? data.colorTempMin.value
          : this.colorTempMin,
      colorTempMax: data.colorTempMax.present
          ? data.colorTempMax.value
          : this.colorTempMax,
      isLukaCompatible: data.isLukaCompatible.present
          ? data.isLukaCompatible.value
          : this.isLukaCompatible,
      lukaFixtureId: data.lukaFixtureId.present
          ? data.lukaFixtureId.value
          : this.lukaFixtureId,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Light(')
          ..write('id: $id, ')
          ..write('brand: $brand, ')
          ..write('model: $model, ')
          ..write('lightType: $lightType, ')
          ..write('powerW: $powerW, ')
          ..write('colorTempMin: $colorTempMin, ')
          ..write('colorTempMax: $colorTempMax, ')
          ..write('isLukaCompatible: $isLukaCompatible, ')
          ..write('lukaFixtureId: $lukaFixtureId, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    brand,
    model,
    lightType,
    powerW,
    colorTempMin,
    colorTempMax,
    isLukaCompatible,
    lukaFixtureId,
    notes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Light &&
          other.id == this.id &&
          other.brand == this.brand &&
          other.model == this.model &&
          other.lightType == this.lightType &&
          other.powerW == this.powerW &&
          other.colorTempMin == this.colorTempMin &&
          other.colorTempMax == this.colorTempMax &&
          other.isLukaCompatible == this.isLukaCompatible &&
          other.lukaFixtureId == this.lukaFixtureId &&
          other.notes == this.notes);
}

class LightsCompanion extends UpdateCompanion<Light> {
  final Value<int> id;
  final Value<String> brand;
  final Value<String> model;
  final Value<String> lightType;
  final Value<int> powerW;
  final Value<int> colorTempMin;
  final Value<int> colorTempMax;
  final Value<bool> isLukaCompatible;
  final Value<String?> lukaFixtureId;
  final Value<String?> notes;
  const LightsCompanion({
    this.id = const Value.absent(),
    this.brand = const Value.absent(),
    this.model = const Value.absent(),
    this.lightType = const Value.absent(),
    this.powerW = const Value.absent(),
    this.colorTempMin = const Value.absent(),
    this.colorTempMax = const Value.absent(),
    this.isLukaCompatible = const Value.absent(),
    this.lukaFixtureId = const Value.absent(),
    this.notes = const Value.absent(),
  });
  LightsCompanion.insert({
    this.id = const Value.absent(),
    required String brand,
    required String model,
    required String lightType,
    required int powerW,
    required int colorTempMin,
    required int colorTempMax,
    this.isLukaCompatible = const Value.absent(),
    this.lukaFixtureId = const Value.absent(),
    this.notes = const Value.absent(),
  }) : brand = Value(brand),
       model = Value(model),
       lightType = Value(lightType),
       powerW = Value(powerW),
       colorTempMin = Value(colorTempMin),
       colorTempMax = Value(colorTempMax);
  static Insertable<Light> custom({
    Expression<int>? id,
    Expression<String>? brand,
    Expression<String>? model,
    Expression<String>? lightType,
    Expression<int>? powerW,
    Expression<int>? colorTempMin,
    Expression<int>? colorTempMax,
    Expression<bool>? isLukaCompatible,
    Expression<String>? lukaFixtureId,
    Expression<String>? notes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (brand != null) 'brand': brand,
      if (model != null) 'model': model,
      if (lightType != null) 'light_type': lightType,
      if (powerW != null) 'power_w': powerW,
      if (colorTempMin != null) 'color_temp_min': colorTempMin,
      if (colorTempMax != null) 'color_temp_max': colorTempMax,
      if (isLukaCompatible != null) 'is_luka_compatible': isLukaCompatible,
      if (lukaFixtureId != null) 'luka_fixture_id': lukaFixtureId,
      if (notes != null) 'notes': notes,
    });
  }

  LightsCompanion copyWith({
    Value<int>? id,
    Value<String>? brand,
    Value<String>? model,
    Value<String>? lightType,
    Value<int>? powerW,
    Value<int>? colorTempMin,
    Value<int>? colorTempMax,
    Value<bool>? isLukaCompatible,
    Value<String?>? lukaFixtureId,
    Value<String?>? notes,
  }) {
    return LightsCompanion(
      id: id ?? this.id,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      lightType: lightType ?? this.lightType,
      powerW: powerW ?? this.powerW,
      colorTempMin: colorTempMin ?? this.colorTempMin,
      colorTempMax: colorTempMax ?? this.colorTempMax,
      isLukaCompatible: isLukaCompatible ?? this.isLukaCompatible,
      lukaFixtureId: lukaFixtureId ?? this.lukaFixtureId,
      notes: notes ?? this.notes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (brand.present) {
      map['brand'] = Variable<String>(brand.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (lightType.present) {
      map['light_type'] = Variable<String>(lightType.value);
    }
    if (powerW.present) {
      map['power_w'] = Variable<int>(powerW.value);
    }
    if (colorTempMin.present) {
      map['color_temp_min'] = Variable<int>(colorTempMin.value);
    }
    if (colorTempMax.present) {
      map['color_temp_max'] = Variable<int>(colorTempMax.value);
    }
    if (isLukaCompatible.present) {
      map['is_luka_compatible'] = Variable<bool>(isLukaCompatible.value);
    }
    if (lukaFixtureId.present) {
      map['luka_fixture_id'] = Variable<String>(lukaFixtureId.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LightsCompanion(')
          ..write('id: $id, ')
          ..write('brand: $brand, ')
          ..write('model: $model, ')
          ..write('lightType: $lightType, ')
          ..write('powerW: $powerW, ')
          ..write('colorTempMin: $colorTempMin, ')
          ..write('colorTempMax: $colorTempMax, ')
          ..write('isLukaCompatible: $isLukaCompatible, ')
          ..write('lukaFixtureId: $lukaFixtureId, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

class $ProjectEquipmentTable extends ProjectEquipment
    with TableInfo<$ProjectEquipmentTable, ProjectEquipmentData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectEquipmentTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<int> projectId = GeneratedColumn<int>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id)',
    ),
  );
  static const VerificationMeta _equipmentTypeMeta = const VerificationMeta(
    'equipmentType',
  );
  @override
  late final GeneratedColumn<String> equipmentType = GeneratedColumn<String>(
    'equipment_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _equipmentIdMeta = const VerificationMeta(
    'equipmentId',
  );
  @override
  late final GeneratedColumn<int> equipmentId = GeneratedColumn<int>(
    'equipment_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('rental'),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('available'),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    equipmentType,
    equipmentId,
    source,
    status,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'project_equipment';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProjectEquipmentData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('equipment_type')) {
      context.handle(
        _equipmentTypeMeta,
        equipmentType.isAcceptableOrUnknown(
          data['equipment_type']!,
          _equipmentTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_equipmentTypeMeta);
    }
    if (data.containsKey('equipment_id')) {
      context.handle(
        _equipmentIdMeta,
        equipmentId.isAcceptableOrUnknown(
          data['equipment_id']!,
          _equipmentIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_equipmentIdMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProjectEquipmentData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProjectEquipmentData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}project_id'],
      )!,
      equipmentType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}equipment_type'],
      )!,
      equipmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}equipment_id'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $ProjectEquipmentTable createAlias(String alias) {
    return $ProjectEquipmentTable(attachedDatabase, alias);
  }
}

class ProjectEquipmentData extends DataClass
    implements Insertable<ProjectEquipmentData> {
  final int id;
  final int projectId;
  final String equipmentType;
  final int equipmentId;
  final String source;
  final String status;
  final String? notes;
  const ProjectEquipmentData({
    required this.id,
    required this.projectId,
    required this.equipmentType,
    required this.equipmentId,
    required this.source,
    required this.status,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['project_id'] = Variable<int>(projectId);
    map['equipment_type'] = Variable<String>(equipmentType);
    map['equipment_id'] = Variable<int>(equipmentId);
    map['source'] = Variable<String>(source);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  ProjectEquipmentCompanion toCompanion(bool nullToAbsent) {
    return ProjectEquipmentCompanion(
      id: Value(id),
      projectId: Value(projectId),
      equipmentType: Value(equipmentType),
      equipmentId: Value(equipmentId),
      source: Value(source),
      status: Value(status),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory ProjectEquipmentData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProjectEquipmentData(
      id: serializer.fromJson<int>(json['id']),
      projectId: serializer.fromJson<int>(json['projectId']),
      equipmentType: serializer.fromJson<String>(json['equipmentType']),
      equipmentId: serializer.fromJson<int>(json['equipmentId']),
      source: serializer.fromJson<String>(json['source']),
      status: serializer.fromJson<String>(json['status']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'projectId': serializer.toJson<int>(projectId),
      'equipmentType': serializer.toJson<String>(equipmentType),
      'equipmentId': serializer.toJson<int>(equipmentId),
      'source': serializer.toJson<String>(source),
      'status': serializer.toJson<String>(status),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  ProjectEquipmentData copyWith({
    int? id,
    int? projectId,
    String? equipmentType,
    int? equipmentId,
    String? source,
    String? status,
    Value<String?> notes = const Value.absent(),
  }) => ProjectEquipmentData(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    equipmentType: equipmentType ?? this.equipmentType,
    equipmentId: equipmentId ?? this.equipmentId,
    source: source ?? this.source,
    status: status ?? this.status,
    notes: notes.present ? notes.value : this.notes,
  );
  ProjectEquipmentData copyWithCompanion(ProjectEquipmentCompanion data) {
    return ProjectEquipmentData(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      equipmentType: data.equipmentType.present
          ? data.equipmentType.value
          : this.equipmentType,
      equipmentId: data.equipmentId.present
          ? data.equipmentId.value
          : this.equipmentId,
      source: data.source.present ? data.source.value : this.source,
      status: data.status.present ? data.status.value : this.status,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProjectEquipmentData(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('equipmentType: $equipmentType, ')
          ..write('equipmentId: $equipmentId, ')
          ..write('source: $source, ')
          ..write('status: $status, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    equipmentType,
    equipmentId,
    source,
    status,
    notes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectEquipmentData &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.equipmentType == this.equipmentType &&
          other.equipmentId == this.equipmentId &&
          other.source == this.source &&
          other.status == this.status &&
          other.notes == this.notes);
}

class ProjectEquipmentCompanion extends UpdateCompanion<ProjectEquipmentData> {
  final Value<int> id;
  final Value<int> projectId;
  final Value<String> equipmentType;
  final Value<int> equipmentId;
  final Value<String> source;
  final Value<String> status;
  final Value<String?> notes;
  const ProjectEquipmentCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.equipmentType = const Value.absent(),
    this.equipmentId = const Value.absent(),
    this.source = const Value.absent(),
    this.status = const Value.absent(),
    this.notes = const Value.absent(),
  });
  ProjectEquipmentCompanion.insert({
    this.id = const Value.absent(),
    required int projectId,
    required String equipmentType,
    required int equipmentId,
    this.source = const Value.absent(),
    this.status = const Value.absent(),
    this.notes = const Value.absent(),
  }) : projectId = Value(projectId),
       equipmentType = Value(equipmentType),
       equipmentId = Value(equipmentId);
  static Insertable<ProjectEquipmentData> custom({
    Expression<int>? id,
    Expression<int>? projectId,
    Expression<String>? equipmentType,
    Expression<int>? equipmentId,
    Expression<String>? source,
    Expression<String>? status,
    Expression<String>? notes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (equipmentType != null) 'equipment_type': equipmentType,
      if (equipmentId != null) 'equipment_id': equipmentId,
      if (source != null) 'source': source,
      if (status != null) 'status': status,
      if (notes != null) 'notes': notes,
    });
  }

  ProjectEquipmentCompanion copyWith({
    Value<int>? id,
    Value<int>? projectId,
    Value<String>? equipmentType,
    Value<int>? equipmentId,
    Value<String>? source,
    Value<String>? status,
    Value<String?>? notes,
  }) {
    return ProjectEquipmentCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      equipmentType: equipmentType ?? this.equipmentType,
      equipmentId: equipmentId ?? this.equipmentId,
      source: source ?? this.source,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<int>(projectId.value);
    }
    if (equipmentType.present) {
      map['equipment_type'] = Variable<String>(equipmentType.value);
    }
    if (equipmentId.present) {
      map['equipment_id'] = Variable<int>(equipmentId.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectEquipmentCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('equipmentType: $equipmentType, ')
          ..write('equipmentId: $equipmentId, ')
          ..write('source: $source, ')
          ..write('status: $status, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

class $LookBiblesTable extends LookBibles
    with TableInfo<$LookBiblesTable, LookBible> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LookBiblesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<int> projectId = GeneratedColumn<int>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id)',
    ),
  );
  static const VerificationMeta _visualConceptMeta = const VerificationMeta(
    'visualConcept',
  );
  @override
  late final GeneratedColumn<String> visualConcept = GeneratedColumn<String>(
    'visual_concept',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorPaletteMeta = const VerificationMeta(
    'colorPalette',
  );
  @override
  late final GeneratedColumn<String> colorPalette = GeneratedColumn<String>(
    'color_palette',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lutNameMeta = const VerificationMeta(
    'lutName',
  );
  @override
  late final GeneratedColumn<String> lutName = GeneratedColumn<String>(
    'lut_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _filmReferencesMeta = const VerificationMeta(
    'filmReferences',
  );
  @override
  late final GeneratedColumn<String> filmReferences = GeneratedColumn<String>(
    'film_references',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lightingPhilosophyMeta =
      const VerificationMeta('lightingPhilosophy');
  @override
  late final GeneratedColumn<String> lightingPhilosophy =
      GeneratedColumn<String>(
        'lighting_philosophy',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _contrastStyleMeta = const VerificationMeta(
    'contrastStyle',
  );
  @override
  late final GeneratedColumn<String> contrastStyle = GeneratedColumn<String>(
    'contrast_style',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _actOneNotesMeta = const VerificationMeta(
    'actOneNotes',
  );
  @override
  late final GeneratedColumn<String> actOneNotes = GeneratedColumn<String>(
    'act_one_notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _actTwoNotesMeta = const VerificationMeta(
    'actTwoNotes',
  );
  @override
  late final GeneratedColumn<String> actTwoNotes = GeneratedColumn<String>(
    'act_two_notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _actThreeNotesMeta = const VerificationMeta(
    'actThreeNotes',
  );
  @override
  late final GeneratedColumn<String> actThreeNotes = GeneratedColumn<String>(
    'act_three_notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _moodboardImagesMeta = const VerificationMeta(
    'moodboardImages',
  );
  @override
  late final GeneratedColumn<String> moodboardImages = GeneratedColumn<String>(
    'moodboard_images',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    visualConcept,
    colorPalette,
    lutName,
    filmReferences,
    lightingPhilosophy,
    contrastStyle,
    actOneNotes,
    actTwoNotes,
    actThreeNotes,
    moodboardImages,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'look_bibles';
  @override
  VerificationContext validateIntegrity(
    Insertable<LookBible> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('visual_concept')) {
      context.handle(
        _visualConceptMeta,
        visualConcept.isAcceptableOrUnknown(
          data['visual_concept']!,
          _visualConceptMeta,
        ),
      );
    }
    if (data.containsKey('color_palette')) {
      context.handle(
        _colorPaletteMeta,
        colorPalette.isAcceptableOrUnknown(
          data['color_palette']!,
          _colorPaletteMeta,
        ),
      );
    }
    if (data.containsKey('lut_name')) {
      context.handle(
        _lutNameMeta,
        lutName.isAcceptableOrUnknown(data['lut_name']!, _lutNameMeta),
      );
    }
    if (data.containsKey('film_references')) {
      context.handle(
        _filmReferencesMeta,
        filmReferences.isAcceptableOrUnknown(
          data['film_references']!,
          _filmReferencesMeta,
        ),
      );
    }
    if (data.containsKey('lighting_philosophy')) {
      context.handle(
        _lightingPhilosophyMeta,
        lightingPhilosophy.isAcceptableOrUnknown(
          data['lighting_philosophy']!,
          _lightingPhilosophyMeta,
        ),
      );
    }
    if (data.containsKey('contrast_style')) {
      context.handle(
        _contrastStyleMeta,
        contrastStyle.isAcceptableOrUnknown(
          data['contrast_style']!,
          _contrastStyleMeta,
        ),
      );
    }
    if (data.containsKey('act_one_notes')) {
      context.handle(
        _actOneNotesMeta,
        actOneNotes.isAcceptableOrUnknown(
          data['act_one_notes']!,
          _actOneNotesMeta,
        ),
      );
    }
    if (data.containsKey('act_two_notes')) {
      context.handle(
        _actTwoNotesMeta,
        actTwoNotes.isAcceptableOrUnknown(
          data['act_two_notes']!,
          _actTwoNotesMeta,
        ),
      );
    }
    if (data.containsKey('act_three_notes')) {
      context.handle(
        _actThreeNotesMeta,
        actThreeNotes.isAcceptableOrUnknown(
          data['act_three_notes']!,
          _actThreeNotesMeta,
        ),
      );
    }
    if (data.containsKey('moodboard_images')) {
      context.handle(
        _moodboardImagesMeta,
        moodboardImages.isAcceptableOrUnknown(
          data['moodboard_images']!,
          _moodboardImagesMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LookBible map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LookBible(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}project_id'],
      )!,
      visualConcept: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}visual_concept'],
      ),
      colorPalette: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_palette'],
      ),
      lutName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lut_name'],
      ),
      filmReferences: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}film_references'],
      ),
      lightingPhilosophy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lighting_philosophy'],
      ),
      contrastStyle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contrast_style'],
      ),
      actOneNotes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}act_one_notes'],
      ),
      actTwoNotes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}act_two_notes'],
      ),
      actThreeNotes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}act_three_notes'],
      ),
      moodboardImages: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}moodboard_images'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LookBiblesTable createAlias(String alias) {
    return $LookBiblesTable(attachedDatabase, alias);
  }
}

class LookBible extends DataClass implements Insertable<LookBible> {
  final int id;
  final int projectId;
  final String? visualConcept;
  final String? colorPalette;
  final String? lutName;
  final String? filmReferences;
  final String? lightingPhilosophy;
  final String? contrastStyle;
  final String? actOneNotes;
  final String? actTwoNotes;
  final String? actThreeNotes;
  final String? moodboardImages;
  final DateTime updatedAt;
  const LookBible({
    required this.id,
    required this.projectId,
    this.visualConcept,
    this.colorPalette,
    this.lutName,
    this.filmReferences,
    this.lightingPhilosophy,
    this.contrastStyle,
    this.actOneNotes,
    this.actTwoNotes,
    this.actThreeNotes,
    this.moodboardImages,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['project_id'] = Variable<int>(projectId);
    if (!nullToAbsent || visualConcept != null) {
      map['visual_concept'] = Variable<String>(visualConcept);
    }
    if (!nullToAbsent || colorPalette != null) {
      map['color_palette'] = Variable<String>(colorPalette);
    }
    if (!nullToAbsent || lutName != null) {
      map['lut_name'] = Variable<String>(lutName);
    }
    if (!nullToAbsent || filmReferences != null) {
      map['film_references'] = Variable<String>(filmReferences);
    }
    if (!nullToAbsent || lightingPhilosophy != null) {
      map['lighting_philosophy'] = Variable<String>(lightingPhilosophy);
    }
    if (!nullToAbsent || contrastStyle != null) {
      map['contrast_style'] = Variable<String>(contrastStyle);
    }
    if (!nullToAbsent || actOneNotes != null) {
      map['act_one_notes'] = Variable<String>(actOneNotes);
    }
    if (!nullToAbsent || actTwoNotes != null) {
      map['act_two_notes'] = Variable<String>(actTwoNotes);
    }
    if (!nullToAbsent || actThreeNotes != null) {
      map['act_three_notes'] = Variable<String>(actThreeNotes);
    }
    if (!nullToAbsent || moodboardImages != null) {
      map['moodboard_images'] = Variable<String>(moodboardImages);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LookBiblesCompanion toCompanion(bool nullToAbsent) {
    return LookBiblesCompanion(
      id: Value(id),
      projectId: Value(projectId),
      visualConcept: visualConcept == null && nullToAbsent
          ? const Value.absent()
          : Value(visualConcept),
      colorPalette: colorPalette == null && nullToAbsent
          ? const Value.absent()
          : Value(colorPalette),
      lutName: lutName == null && nullToAbsent
          ? const Value.absent()
          : Value(lutName),
      filmReferences: filmReferences == null && nullToAbsent
          ? const Value.absent()
          : Value(filmReferences),
      lightingPhilosophy: lightingPhilosophy == null && nullToAbsent
          ? const Value.absent()
          : Value(lightingPhilosophy),
      contrastStyle: contrastStyle == null && nullToAbsent
          ? const Value.absent()
          : Value(contrastStyle),
      actOneNotes: actOneNotes == null && nullToAbsent
          ? const Value.absent()
          : Value(actOneNotes),
      actTwoNotes: actTwoNotes == null && nullToAbsent
          ? const Value.absent()
          : Value(actTwoNotes),
      actThreeNotes: actThreeNotes == null && nullToAbsent
          ? const Value.absent()
          : Value(actThreeNotes),
      moodboardImages: moodboardImages == null && nullToAbsent
          ? const Value.absent()
          : Value(moodboardImages),
      updatedAt: Value(updatedAt),
    );
  }

  factory LookBible.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LookBible(
      id: serializer.fromJson<int>(json['id']),
      projectId: serializer.fromJson<int>(json['projectId']),
      visualConcept: serializer.fromJson<String?>(json['visualConcept']),
      colorPalette: serializer.fromJson<String?>(json['colorPalette']),
      lutName: serializer.fromJson<String?>(json['lutName']),
      filmReferences: serializer.fromJson<String?>(json['filmReferences']),
      lightingPhilosophy: serializer.fromJson<String?>(
        json['lightingPhilosophy'],
      ),
      contrastStyle: serializer.fromJson<String?>(json['contrastStyle']),
      actOneNotes: serializer.fromJson<String?>(json['actOneNotes']),
      actTwoNotes: serializer.fromJson<String?>(json['actTwoNotes']),
      actThreeNotes: serializer.fromJson<String?>(json['actThreeNotes']),
      moodboardImages: serializer.fromJson<String?>(json['moodboardImages']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'projectId': serializer.toJson<int>(projectId),
      'visualConcept': serializer.toJson<String?>(visualConcept),
      'colorPalette': serializer.toJson<String?>(colorPalette),
      'lutName': serializer.toJson<String?>(lutName),
      'filmReferences': serializer.toJson<String?>(filmReferences),
      'lightingPhilosophy': serializer.toJson<String?>(lightingPhilosophy),
      'contrastStyle': serializer.toJson<String?>(contrastStyle),
      'actOneNotes': serializer.toJson<String?>(actOneNotes),
      'actTwoNotes': serializer.toJson<String?>(actTwoNotes),
      'actThreeNotes': serializer.toJson<String?>(actThreeNotes),
      'moodboardImages': serializer.toJson<String?>(moodboardImages),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LookBible copyWith({
    int? id,
    int? projectId,
    Value<String?> visualConcept = const Value.absent(),
    Value<String?> colorPalette = const Value.absent(),
    Value<String?> lutName = const Value.absent(),
    Value<String?> filmReferences = const Value.absent(),
    Value<String?> lightingPhilosophy = const Value.absent(),
    Value<String?> contrastStyle = const Value.absent(),
    Value<String?> actOneNotes = const Value.absent(),
    Value<String?> actTwoNotes = const Value.absent(),
    Value<String?> actThreeNotes = const Value.absent(),
    Value<String?> moodboardImages = const Value.absent(),
    DateTime? updatedAt,
  }) => LookBible(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    visualConcept: visualConcept.present
        ? visualConcept.value
        : this.visualConcept,
    colorPalette: colorPalette.present ? colorPalette.value : this.colorPalette,
    lutName: lutName.present ? lutName.value : this.lutName,
    filmReferences: filmReferences.present
        ? filmReferences.value
        : this.filmReferences,
    lightingPhilosophy: lightingPhilosophy.present
        ? lightingPhilosophy.value
        : this.lightingPhilosophy,
    contrastStyle: contrastStyle.present
        ? contrastStyle.value
        : this.contrastStyle,
    actOneNotes: actOneNotes.present ? actOneNotes.value : this.actOneNotes,
    actTwoNotes: actTwoNotes.present ? actTwoNotes.value : this.actTwoNotes,
    actThreeNotes: actThreeNotes.present
        ? actThreeNotes.value
        : this.actThreeNotes,
    moodboardImages: moodboardImages.present
        ? moodboardImages.value
        : this.moodboardImages,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LookBible copyWithCompanion(LookBiblesCompanion data) {
    return LookBible(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      visualConcept: data.visualConcept.present
          ? data.visualConcept.value
          : this.visualConcept,
      colorPalette: data.colorPalette.present
          ? data.colorPalette.value
          : this.colorPalette,
      lutName: data.lutName.present ? data.lutName.value : this.lutName,
      filmReferences: data.filmReferences.present
          ? data.filmReferences.value
          : this.filmReferences,
      lightingPhilosophy: data.lightingPhilosophy.present
          ? data.lightingPhilosophy.value
          : this.lightingPhilosophy,
      contrastStyle: data.contrastStyle.present
          ? data.contrastStyle.value
          : this.contrastStyle,
      actOneNotes: data.actOneNotes.present
          ? data.actOneNotes.value
          : this.actOneNotes,
      actTwoNotes: data.actTwoNotes.present
          ? data.actTwoNotes.value
          : this.actTwoNotes,
      actThreeNotes: data.actThreeNotes.present
          ? data.actThreeNotes.value
          : this.actThreeNotes,
      moodboardImages: data.moodboardImages.present
          ? data.moodboardImages.value
          : this.moodboardImages,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LookBible(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('visualConcept: $visualConcept, ')
          ..write('colorPalette: $colorPalette, ')
          ..write('lutName: $lutName, ')
          ..write('filmReferences: $filmReferences, ')
          ..write('lightingPhilosophy: $lightingPhilosophy, ')
          ..write('contrastStyle: $contrastStyle, ')
          ..write('actOneNotes: $actOneNotes, ')
          ..write('actTwoNotes: $actTwoNotes, ')
          ..write('actThreeNotes: $actThreeNotes, ')
          ..write('moodboardImages: $moodboardImages, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    visualConcept,
    colorPalette,
    lutName,
    filmReferences,
    lightingPhilosophy,
    contrastStyle,
    actOneNotes,
    actTwoNotes,
    actThreeNotes,
    moodboardImages,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LookBible &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.visualConcept == this.visualConcept &&
          other.colorPalette == this.colorPalette &&
          other.lutName == this.lutName &&
          other.filmReferences == this.filmReferences &&
          other.lightingPhilosophy == this.lightingPhilosophy &&
          other.contrastStyle == this.contrastStyle &&
          other.actOneNotes == this.actOneNotes &&
          other.actTwoNotes == this.actTwoNotes &&
          other.actThreeNotes == this.actThreeNotes &&
          other.moodboardImages == this.moodboardImages &&
          other.updatedAt == this.updatedAt);
}

class LookBiblesCompanion extends UpdateCompanion<LookBible> {
  final Value<int> id;
  final Value<int> projectId;
  final Value<String?> visualConcept;
  final Value<String?> colorPalette;
  final Value<String?> lutName;
  final Value<String?> filmReferences;
  final Value<String?> lightingPhilosophy;
  final Value<String?> contrastStyle;
  final Value<String?> actOneNotes;
  final Value<String?> actTwoNotes;
  final Value<String?> actThreeNotes;
  final Value<String?> moodboardImages;
  final Value<DateTime> updatedAt;
  const LookBiblesCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.visualConcept = const Value.absent(),
    this.colorPalette = const Value.absent(),
    this.lutName = const Value.absent(),
    this.filmReferences = const Value.absent(),
    this.lightingPhilosophy = const Value.absent(),
    this.contrastStyle = const Value.absent(),
    this.actOneNotes = const Value.absent(),
    this.actTwoNotes = const Value.absent(),
    this.actThreeNotes = const Value.absent(),
    this.moodboardImages = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  LookBiblesCompanion.insert({
    this.id = const Value.absent(),
    required int projectId,
    this.visualConcept = const Value.absent(),
    this.colorPalette = const Value.absent(),
    this.lutName = const Value.absent(),
    this.filmReferences = const Value.absent(),
    this.lightingPhilosophy = const Value.absent(),
    this.contrastStyle = const Value.absent(),
    this.actOneNotes = const Value.absent(),
    this.actTwoNotes = const Value.absent(),
    this.actThreeNotes = const Value.absent(),
    this.moodboardImages = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : projectId = Value(projectId);
  static Insertable<LookBible> custom({
    Expression<int>? id,
    Expression<int>? projectId,
    Expression<String>? visualConcept,
    Expression<String>? colorPalette,
    Expression<String>? lutName,
    Expression<String>? filmReferences,
    Expression<String>? lightingPhilosophy,
    Expression<String>? contrastStyle,
    Expression<String>? actOneNotes,
    Expression<String>? actTwoNotes,
    Expression<String>? actThreeNotes,
    Expression<String>? moodboardImages,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (visualConcept != null) 'visual_concept': visualConcept,
      if (colorPalette != null) 'color_palette': colorPalette,
      if (lutName != null) 'lut_name': lutName,
      if (filmReferences != null) 'film_references': filmReferences,
      if (lightingPhilosophy != null) 'lighting_philosophy': lightingPhilosophy,
      if (contrastStyle != null) 'contrast_style': contrastStyle,
      if (actOneNotes != null) 'act_one_notes': actOneNotes,
      if (actTwoNotes != null) 'act_two_notes': actTwoNotes,
      if (actThreeNotes != null) 'act_three_notes': actThreeNotes,
      if (moodboardImages != null) 'moodboard_images': moodboardImages,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  LookBiblesCompanion copyWith({
    Value<int>? id,
    Value<int>? projectId,
    Value<String?>? visualConcept,
    Value<String?>? colorPalette,
    Value<String?>? lutName,
    Value<String?>? filmReferences,
    Value<String?>? lightingPhilosophy,
    Value<String?>? contrastStyle,
    Value<String?>? actOneNotes,
    Value<String?>? actTwoNotes,
    Value<String?>? actThreeNotes,
    Value<String?>? moodboardImages,
    Value<DateTime>? updatedAt,
  }) {
    return LookBiblesCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      visualConcept: visualConcept ?? this.visualConcept,
      colorPalette: colorPalette ?? this.colorPalette,
      lutName: lutName ?? this.lutName,
      filmReferences: filmReferences ?? this.filmReferences,
      lightingPhilosophy: lightingPhilosophy ?? this.lightingPhilosophy,
      contrastStyle: contrastStyle ?? this.contrastStyle,
      actOneNotes: actOneNotes ?? this.actOneNotes,
      actTwoNotes: actTwoNotes ?? this.actTwoNotes,
      actThreeNotes: actThreeNotes ?? this.actThreeNotes,
      moodboardImages: moodboardImages ?? this.moodboardImages,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<int>(projectId.value);
    }
    if (visualConcept.present) {
      map['visual_concept'] = Variable<String>(visualConcept.value);
    }
    if (colorPalette.present) {
      map['color_palette'] = Variable<String>(colorPalette.value);
    }
    if (lutName.present) {
      map['lut_name'] = Variable<String>(lutName.value);
    }
    if (filmReferences.present) {
      map['film_references'] = Variable<String>(filmReferences.value);
    }
    if (lightingPhilosophy.present) {
      map['lighting_philosophy'] = Variable<String>(lightingPhilosophy.value);
    }
    if (contrastStyle.present) {
      map['contrast_style'] = Variable<String>(contrastStyle.value);
    }
    if (actOneNotes.present) {
      map['act_one_notes'] = Variable<String>(actOneNotes.value);
    }
    if (actTwoNotes.present) {
      map['act_two_notes'] = Variable<String>(actTwoNotes.value);
    }
    if (actThreeNotes.present) {
      map['act_three_notes'] = Variable<String>(actThreeNotes.value);
    }
    if (moodboardImages.present) {
      map['moodboard_images'] = Variable<String>(moodboardImages.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LookBiblesCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('visualConcept: $visualConcept, ')
          ..write('colorPalette: $colorPalette, ')
          ..write('lutName: $lutName, ')
          ..write('filmReferences: $filmReferences, ')
          ..write('lightingPhilosophy: $lightingPhilosophy, ')
          ..write('contrastStyle: $contrastStyle, ')
          ..write('actOneNotes: $actOneNotes, ')
          ..write('actTwoNotes: $actTwoNotes, ')
          ..write('actThreeNotes: $actThreeNotes, ')
          ..write('moodboardImages: $moodboardImages, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $ProjectAnnotatedPdfsTable extends ProjectAnnotatedPdfs
    with TableInfo<$ProjectAnnotatedPdfsTable, ProjectAnnotatedPdf> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectAnnotatedPdfsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<int> projectId = GeneratedColumn<int>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id)',
    ),
  );
  static const VerificationMeta _moduleTypeMeta = const VerificationMeta(
    'moduleType',
  );
  @override
  late final GeneratedColumn<String> moduleType = GeneratedColumn<String>(
    'module_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pdfPathMeta = const VerificationMeta(
    'pdfPath',
  );
  @override
  late final GeneratedColumn<String> pdfPath = GeneratedColumn<String>(
    'pdf_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _importedAtMeta = const VerificationMeta(
    'importedAt',
  );
  @override
  late final GeneratedColumn<DateTime> importedAt = GeneratedColumn<DateTime>(
    'imported_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    moduleType,
    pdfPath,
    importedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'project_annotated_pdfs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProjectAnnotatedPdf> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('module_type')) {
      context.handle(
        _moduleTypeMeta,
        moduleType.isAcceptableOrUnknown(data['module_type']!, _moduleTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_moduleTypeMeta);
    }
    if (data.containsKey('pdf_path')) {
      context.handle(
        _pdfPathMeta,
        pdfPath.isAcceptableOrUnknown(data['pdf_path']!, _pdfPathMeta),
      );
    } else if (isInserting) {
      context.missing(_pdfPathMeta);
    }
    if (data.containsKey('imported_at')) {
      context.handle(
        _importedAtMeta,
        importedAt.isAcceptableOrUnknown(data['imported_at']!, _importedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProjectAnnotatedPdf map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProjectAnnotatedPdf(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}project_id'],
      )!,
      moduleType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}module_type'],
      )!,
      pdfPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pdf_path'],
      )!,
      importedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}imported_at'],
      )!,
    );
  }

  @override
  $ProjectAnnotatedPdfsTable createAlias(String alias) {
    return $ProjectAnnotatedPdfsTable(attachedDatabase, alias);
  }
}

class ProjectAnnotatedPdf extends DataClass
    implements Insertable<ProjectAnnotatedPdf> {
  final int id;
  final int projectId;
  final String moduleType;
  final String pdfPath;
  final DateTime importedAt;
  const ProjectAnnotatedPdf({
    required this.id,
    required this.projectId,
    required this.moduleType,
    required this.pdfPath,
    required this.importedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['project_id'] = Variable<int>(projectId);
    map['module_type'] = Variable<String>(moduleType);
    map['pdf_path'] = Variable<String>(pdfPath);
    map['imported_at'] = Variable<DateTime>(importedAt);
    return map;
  }

  ProjectAnnotatedPdfsCompanion toCompanion(bool nullToAbsent) {
    return ProjectAnnotatedPdfsCompanion(
      id: Value(id),
      projectId: Value(projectId),
      moduleType: Value(moduleType),
      pdfPath: Value(pdfPath),
      importedAt: Value(importedAt),
    );
  }

  factory ProjectAnnotatedPdf.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProjectAnnotatedPdf(
      id: serializer.fromJson<int>(json['id']),
      projectId: serializer.fromJson<int>(json['projectId']),
      moduleType: serializer.fromJson<String>(json['moduleType']),
      pdfPath: serializer.fromJson<String>(json['pdfPath']),
      importedAt: serializer.fromJson<DateTime>(json['importedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'projectId': serializer.toJson<int>(projectId),
      'moduleType': serializer.toJson<String>(moduleType),
      'pdfPath': serializer.toJson<String>(pdfPath),
      'importedAt': serializer.toJson<DateTime>(importedAt),
    };
  }

  ProjectAnnotatedPdf copyWith({
    int? id,
    int? projectId,
    String? moduleType,
    String? pdfPath,
    DateTime? importedAt,
  }) => ProjectAnnotatedPdf(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    moduleType: moduleType ?? this.moduleType,
    pdfPath: pdfPath ?? this.pdfPath,
    importedAt: importedAt ?? this.importedAt,
  );
  ProjectAnnotatedPdf copyWithCompanion(ProjectAnnotatedPdfsCompanion data) {
    return ProjectAnnotatedPdf(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      moduleType: data.moduleType.present
          ? data.moduleType.value
          : this.moduleType,
      pdfPath: data.pdfPath.present ? data.pdfPath.value : this.pdfPath,
      importedAt: data.importedAt.present
          ? data.importedAt.value
          : this.importedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProjectAnnotatedPdf(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('moduleType: $moduleType, ')
          ..write('pdfPath: $pdfPath, ')
          ..write('importedAt: $importedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, projectId, moduleType, pdfPath, importedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectAnnotatedPdf &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.moduleType == this.moduleType &&
          other.pdfPath == this.pdfPath &&
          other.importedAt == this.importedAt);
}

class ProjectAnnotatedPdfsCompanion
    extends UpdateCompanion<ProjectAnnotatedPdf> {
  final Value<int> id;
  final Value<int> projectId;
  final Value<String> moduleType;
  final Value<String> pdfPath;
  final Value<DateTime> importedAt;
  const ProjectAnnotatedPdfsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.moduleType = const Value.absent(),
    this.pdfPath = const Value.absent(),
    this.importedAt = const Value.absent(),
  });
  ProjectAnnotatedPdfsCompanion.insert({
    this.id = const Value.absent(),
    required int projectId,
    required String moduleType,
    required String pdfPath,
    this.importedAt = const Value.absent(),
  }) : projectId = Value(projectId),
       moduleType = Value(moduleType),
       pdfPath = Value(pdfPath);
  static Insertable<ProjectAnnotatedPdf> custom({
    Expression<int>? id,
    Expression<int>? projectId,
    Expression<String>? moduleType,
    Expression<String>? pdfPath,
    Expression<DateTime>? importedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (moduleType != null) 'module_type': moduleType,
      if (pdfPath != null) 'pdf_path': pdfPath,
      if (importedAt != null) 'imported_at': importedAt,
    });
  }

  ProjectAnnotatedPdfsCompanion copyWith({
    Value<int>? id,
    Value<int>? projectId,
    Value<String>? moduleType,
    Value<String>? pdfPath,
    Value<DateTime>? importedAt,
  }) {
    return ProjectAnnotatedPdfsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      moduleType: moduleType ?? this.moduleType,
      pdfPath: pdfPath ?? this.pdfPath,
      importedAt: importedAt ?? this.importedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<int>(projectId.value);
    }
    if (moduleType.present) {
      map['module_type'] = Variable<String>(moduleType.value);
    }
    if (pdfPath.present) {
      map['pdf_path'] = Variable<String>(pdfPath.value);
    }
    if (importedAt.present) {
      map['imported_at'] = Variable<DateTime>(importedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectAnnotatedPdfsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('moduleType: $moduleType, ')
          ..write('pdfPath: $pdfPath, ')
          ..write('importedAt: $importedAt')
          ..write(')'))
        .toString();
  }
}

class $VisualBiblesTable extends VisualBibles
    with TableInfo<$VisualBiblesTable, VisualBible> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VisualBiblesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<int> projectId = GeneratedColumn<int>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id)',
    ),
  );
  static const VerificationMeta _visualConceptMeta = const VerificationMeta(
    'visualConcept',
  );
  @override
  late final GeneratedColumn<String> visualConcept = GeneratedColumn<String>(
    'visual_concept',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _narrativeReferencesMeta =
      const VerificationMeta('narrativeReferences');
  @override
  late final GeneratedColumn<String> narrativeReferences =
      GeneratedColumn<String>(
        'narrative_references',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lightingPhilosophyMeta =
      const VerificationMeta('lightingPhilosophy');
  @override
  late final GeneratedColumn<String> lightingPhilosophy =
      GeneratedColumn<String>(
        'lighting_philosophy',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lightQualityMeta = const VerificationMeta(
    'lightQuality',
  );
  @override
  late final GeneratedColumn<String> lightQuality = GeneratedColumn<String>(
    'light_quality',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contrastStyleMeta = const VerificationMeta(
    'contrastStyle',
  );
  @override
  late final GeneratedColumn<String> contrastStyle = GeneratedColumn<String>(
    'contrast_style',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _keyFillRatioDayMeta = const VerificationMeta(
    'keyFillRatioDay',
  );
  @override
  late final GeneratedColumn<String> keyFillRatioDay = GeneratedColumn<String>(
    'key_fill_ratio_day',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _keyFillRatioNightMeta = const VerificationMeta(
    'keyFillRatioNight',
  );
  @override
  late final GeneratedColumn<String> keyFillRatioNight =
      GeneratedColumn<String>(
        'key_fill_ratio_night',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lightSourceMeta = const VerificationMeta(
    'lightSource',
  );
  @override
  late final GeneratedColumn<String> lightSource = GeneratedColumn<String>(
    'light_source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cameraPhilosophyMeta = const VerificationMeta(
    'cameraPhilosophy',
  );
  @override
  late final GeneratedColumn<String> cameraPhilosophy = GeneratedColumn<String>(
    'camera_philosophy',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _movementStyleMeta = const VerificationMeta(
    'movementStyle',
  );
  @override
  late final GeneratedColumn<String> movementStyle = GeneratedColumn<String>(
    'movement_style',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _preferredMovementsMeta =
      const VerificationMeta('preferredMovements');
  @override
  late final GeneratedColumn<String> preferredMovements =
      GeneratedColumn<String>(
        'preferred_movements',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lensPhilosophyMeta = const VerificationMeta(
    'lensPhilosophy',
  );
  @override
  late final GeneratedColumn<String> lensPhilosophy = GeneratedColumn<String>(
    'lens_philosophy',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _opticTypeMeta = const VerificationMeta(
    'opticType',
  );
  @override
  late final GeneratedColumn<String> opticType = GeneratedColumn<String>(
    'optic_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _primaryFocalLengthsMeta =
      const VerificationMeta('primaryFocalLengths');
  @override
  late final GeneratedColumn<String> primaryFocalLengths =
      GeneratedColumn<String>(
        'primary_focal_lengths',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _primaryLensIdMeta = const VerificationMeta(
    'primaryLensId',
  );
  @override
  late final GeneratedColumn<int> primaryLensId = GeneratedColumn<int>(
    'primary_lens_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES lenses (id)',
    ),
  );
  static const VerificationMeta _aspectRatioMeta = const VerificationMeta(
    'aspectRatio',
  );
  @override
  late final GeneratedColumn<String> aspectRatio = GeneratedColumn<String>(
    'aspect_ratio',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aspectRatioJustificationMeta =
      const VerificationMeta('aspectRatioJustification');
  @override
  late final GeneratedColumn<String> aspectRatioJustification =
      GeneratedColumn<String>(
        'aspect_ratio_justification',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _imageTextureMeta = const VerificationMeta(
    'imageTexture',
  );
  @override
  late final GeneratedColumn<String> imageTexture = GeneratedColumn<String>(
    'image_texture',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _grainLevelMeta = const VerificationMeta(
    'grainLevel',
  );
  @override
  late final GeneratedColumn<String> grainLevel = GeneratedColumn<String>(
    'grain_level',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _highlightBehaviorMeta = const VerificationMeta(
    'highlightBehavior',
  );
  @override
  late final GeneratedColumn<String> highlightBehavior =
      GeneratedColumn<String>(
        'highlight_behavior',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _shadowBehaviorMeta = const VerificationMeta(
    'shadowBehavior',
  );
  @override
  late final GeneratedColumn<String> shadowBehavior = GeneratedColumn<String>(
    'shadow_behavior',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _workingLutNameMeta = const VerificationMeta(
    'workingLutName',
  );
  @override
  late final GeneratedColumn<String> workingLutName = GeneratedColumn<String>(
    'working_lut_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _creativeLutNameMeta = const VerificationMeta(
    'creativeLutName',
  );
  @override
  late final GeneratedColumn<String> creativeLutName = GeneratedColumn<String>(
    'creative_lut_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _creativeLutDescriptionMeta =
      const VerificationMeta('creativeLutDescription');
  @override
  late final GeneratedColumn<String> creativeLutDescription =
      GeneratedColumn<String>(
        'creative_lut_description',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    visualConcept,
    narrativeReferences,
    lightingPhilosophy,
    lightQuality,
    contrastStyle,
    keyFillRatioDay,
    keyFillRatioNight,
    lightSource,
    cameraPhilosophy,
    movementStyle,
    preferredMovements,
    lensPhilosophy,
    opticType,
    primaryFocalLengths,
    primaryLensId,
    aspectRatio,
    aspectRatioJustification,
    imageTexture,
    grainLevel,
    highlightBehavior,
    shadowBehavior,
    workingLutName,
    creativeLutName,
    creativeLutDescription,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'visual_bibles';
  @override
  VerificationContext validateIntegrity(
    Insertable<VisualBible> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('visual_concept')) {
      context.handle(
        _visualConceptMeta,
        visualConcept.isAcceptableOrUnknown(
          data['visual_concept']!,
          _visualConceptMeta,
        ),
      );
    }
    if (data.containsKey('narrative_references')) {
      context.handle(
        _narrativeReferencesMeta,
        narrativeReferences.isAcceptableOrUnknown(
          data['narrative_references']!,
          _narrativeReferencesMeta,
        ),
      );
    }
    if (data.containsKey('lighting_philosophy')) {
      context.handle(
        _lightingPhilosophyMeta,
        lightingPhilosophy.isAcceptableOrUnknown(
          data['lighting_philosophy']!,
          _lightingPhilosophyMeta,
        ),
      );
    }
    if (data.containsKey('light_quality')) {
      context.handle(
        _lightQualityMeta,
        lightQuality.isAcceptableOrUnknown(
          data['light_quality']!,
          _lightQualityMeta,
        ),
      );
    }
    if (data.containsKey('contrast_style')) {
      context.handle(
        _contrastStyleMeta,
        contrastStyle.isAcceptableOrUnknown(
          data['contrast_style']!,
          _contrastStyleMeta,
        ),
      );
    }
    if (data.containsKey('key_fill_ratio_day')) {
      context.handle(
        _keyFillRatioDayMeta,
        keyFillRatioDay.isAcceptableOrUnknown(
          data['key_fill_ratio_day']!,
          _keyFillRatioDayMeta,
        ),
      );
    }
    if (data.containsKey('key_fill_ratio_night')) {
      context.handle(
        _keyFillRatioNightMeta,
        keyFillRatioNight.isAcceptableOrUnknown(
          data['key_fill_ratio_night']!,
          _keyFillRatioNightMeta,
        ),
      );
    }
    if (data.containsKey('light_source')) {
      context.handle(
        _lightSourceMeta,
        lightSource.isAcceptableOrUnknown(
          data['light_source']!,
          _lightSourceMeta,
        ),
      );
    }
    if (data.containsKey('camera_philosophy')) {
      context.handle(
        _cameraPhilosophyMeta,
        cameraPhilosophy.isAcceptableOrUnknown(
          data['camera_philosophy']!,
          _cameraPhilosophyMeta,
        ),
      );
    }
    if (data.containsKey('movement_style')) {
      context.handle(
        _movementStyleMeta,
        movementStyle.isAcceptableOrUnknown(
          data['movement_style']!,
          _movementStyleMeta,
        ),
      );
    }
    if (data.containsKey('preferred_movements')) {
      context.handle(
        _preferredMovementsMeta,
        preferredMovements.isAcceptableOrUnknown(
          data['preferred_movements']!,
          _preferredMovementsMeta,
        ),
      );
    }
    if (data.containsKey('lens_philosophy')) {
      context.handle(
        _lensPhilosophyMeta,
        lensPhilosophy.isAcceptableOrUnknown(
          data['lens_philosophy']!,
          _lensPhilosophyMeta,
        ),
      );
    }
    if (data.containsKey('optic_type')) {
      context.handle(
        _opticTypeMeta,
        opticType.isAcceptableOrUnknown(data['optic_type']!, _opticTypeMeta),
      );
    }
    if (data.containsKey('primary_focal_lengths')) {
      context.handle(
        _primaryFocalLengthsMeta,
        primaryFocalLengths.isAcceptableOrUnknown(
          data['primary_focal_lengths']!,
          _primaryFocalLengthsMeta,
        ),
      );
    }
    if (data.containsKey('primary_lens_id')) {
      context.handle(
        _primaryLensIdMeta,
        primaryLensId.isAcceptableOrUnknown(
          data['primary_lens_id']!,
          _primaryLensIdMeta,
        ),
      );
    }
    if (data.containsKey('aspect_ratio')) {
      context.handle(
        _aspectRatioMeta,
        aspectRatio.isAcceptableOrUnknown(
          data['aspect_ratio']!,
          _aspectRatioMeta,
        ),
      );
    }
    if (data.containsKey('aspect_ratio_justification')) {
      context.handle(
        _aspectRatioJustificationMeta,
        aspectRatioJustification.isAcceptableOrUnknown(
          data['aspect_ratio_justification']!,
          _aspectRatioJustificationMeta,
        ),
      );
    }
    if (data.containsKey('image_texture')) {
      context.handle(
        _imageTextureMeta,
        imageTexture.isAcceptableOrUnknown(
          data['image_texture']!,
          _imageTextureMeta,
        ),
      );
    }
    if (data.containsKey('grain_level')) {
      context.handle(
        _grainLevelMeta,
        grainLevel.isAcceptableOrUnknown(data['grain_level']!, _grainLevelMeta),
      );
    }
    if (data.containsKey('highlight_behavior')) {
      context.handle(
        _highlightBehaviorMeta,
        highlightBehavior.isAcceptableOrUnknown(
          data['highlight_behavior']!,
          _highlightBehaviorMeta,
        ),
      );
    }
    if (data.containsKey('shadow_behavior')) {
      context.handle(
        _shadowBehaviorMeta,
        shadowBehavior.isAcceptableOrUnknown(
          data['shadow_behavior']!,
          _shadowBehaviorMeta,
        ),
      );
    }
    if (data.containsKey('working_lut_name')) {
      context.handle(
        _workingLutNameMeta,
        workingLutName.isAcceptableOrUnknown(
          data['working_lut_name']!,
          _workingLutNameMeta,
        ),
      );
    }
    if (data.containsKey('creative_lut_name')) {
      context.handle(
        _creativeLutNameMeta,
        creativeLutName.isAcceptableOrUnknown(
          data['creative_lut_name']!,
          _creativeLutNameMeta,
        ),
      );
    }
    if (data.containsKey('creative_lut_description')) {
      context.handle(
        _creativeLutDescriptionMeta,
        creativeLutDescription.isAcceptableOrUnknown(
          data['creative_lut_description']!,
          _creativeLutDescriptionMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VisualBible map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VisualBible(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}project_id'],
      )!,
      visualConcept: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}visual_concept'],
      ),
      narrativeReferences: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}narrative_references'],
      ),
      lightingPhilosophy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lighting_philosophy'],
      ),
      lightQuality: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}light_quality'],
      ),
      contrastStyle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contrast_style'],
      ),
      keyFillRatioDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key_fill_ratio_day'],
      ),
      keyFillRatioNight: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key_fill_ratio_night'],
      ),
      lightSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}light_source'],
      ),
      cameraPhilosophy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}camera_philosophy'],
      ),
      movementStyle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}movement_style'],
      ),
      preferredMovements: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preferred_movements'],
      ),
      lensPhilosophy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lens_philosophy'],
      ),
      opticType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}optic_type'],
      ),
      primaryFocalLengths: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}primary_focal_lengths'],
      ),
      primaryLensId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}primary_lens_id'],
      ),
      aspectRatio: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}aspect_ratio'],
      ),
      aspectRatioJustification: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}aspect_ratio_justification'],
      ),
      imageTexture: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_texture'],
      ),
      grainLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}grain_level'],
      ),
      highlightBehavior: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}highlight_behavior'],
      ),
      shadowBehavior: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shadow_behavior'],
      ),
      workingLutName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}working_lut_name'],
      ),
      creativeLutName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}creative_lut_name'],
      ),
      creativeLutDescription: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}creative_lut_description'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $VisualBiblesTable createAlias(String alias) {
    return $VisualBiblesTable(attachedDatabase, alias);
  }
}

class VisualBible extends DataClass implements Insertable<VisualBible> {
  final int id;
  final int projectId;
  final String? visualConcept;
  final String? narrativeReferences;
  final String? lightingPhilosophy;
  final String? lightQuality;
  final String? contrastStyle;
  final String? keyFillRatioDay;
  final String? keyFillRatioNight;
  final String? lightSource;
  final String? cameraPhilosophy;
  final String? movementStyle;
  final String? preferredMovements;
  final String? lensPhilosophy;
  final String? opticType;
  final String? primaryFocalLengths;
  final int? primaryLensId;
  final String? aspectRatio;
  final String? aspectRatioJustification;
  final String? imageTexture;
  final String? grainLevel;
  final String? highlightBehavior;
  final String? shadowBehavior;
  final String? workingLutName;
  final String? creativeLutName;
  final String? creativeLutDescription;
  final DateTime updatedAt;
  const VisualBible({
    required this.id,
    required this.projectId,
    this.visualConcept,
    this.narrativeReferences,
    this.lightingPhilosophy,
    this.lightQuality,
    this.contrastStyle,
    this.keyFillRatioDay,
    this.keyFillRatioNight,
    this.lightSource,
    this.cameraPhilosophy,
    this.movementStyle,
    this.preferredMovements,
    this.lensPhilosophy,
    this.opticType,
    this.primaryFocalLengths,
    this.primaryLensId,
    this.aspectRatio,
    this.aspectRatioJustification,
    this.imageTexture,
    this.grainLevel,
    this.highlightBehavior,
    this.shadowBehavior,
    this.workingLutName,
    this.creativeLutName,
    this.creativeLutDescription,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['project_id'] = Variable<int>(projectId);
    if (!nullToAbsent || visualConcept != null) {
      map['visual_concept'] = Variable<String>(visualConcept);
    }
    if (!nullToAbsent || narrativeReferences != null) {
      map['narrative_references'] = Variable<String>(narrativeReferences);
    }
    if (!nullToAbsent || lightingPhilosophy != null) {
      map['lighting_philosophy'] = Variable<String>(lightingPhilosophy);
    }
    if (!nullToAbsent || lightQuality != null) {
      map['light_quality'] = Variable<String>(lightQuality);
    }
    if (!nullToAbsent || contrastStyle != null) {
      map['contrast_style'] = Variable<String>(contrastStyle);
    }
    if (!nullToAbsent || keyFillRatioDay != null) {
      map['key_fill_ratio_day'] = Variable<String>(keyFillRatioDay);
    }
    if (!nullToAbsent || keyFillRatioNight != null) {
      map['key_fill_ratio_night'] = Variable<String>(keyFillRatioNight);
    }
    if (!nullToAbsent || lightSource != null) {
      map['light_source'] = Variable<String>(lightSource);
    }
    if (!nullToAbsent || cameraPhilosophy != null) {
      map['camera_philosophy'] = Variable<String>(cameraPhilosophy);
    }
    if (!nullToAbsent || movementStyle != null) {
      map['movement_style'] = Variable<String>(movementStyle);
    }
    if (!nullToAbsent || preferredMovements != null) {
      map['preferred_movements'] = Variable<String>(preferredMovements);
    }
    if (!nullToAbsent || lensPhilosophy != null) {
      map['lens_philosophy'] = Variable<String>(lensPhilosophy);
    }
    if (!nullToAbsent || opticType != null) {
      map['optic_type'] = Variable<String>(opticType);
    }
    if (!nullToAbsent || primaryFocalLengths != null) {
      map['primary_focal_lengths'] = Variable<String>(primaryFocalLengths);
    }
    if (!nullToAbsent || primaryLensId != null) {
      map['primary_lens_id'] = Variable<int>(primaryLensId);
    }
    if (!nullToAbsent || aspectRatio != null) {
      map['aspect_ratio'] = Variable<String>(aspectRatio);
    }
    if (!nullToAbsent || aspectRatioJustification != null) {
      map['aspect_ratio_justification'] = Variable<String>(
        aspectRatioJustification,
      );
    }
    if (!nullToAbsent || imageTexture != null) {
      map['image_texture'] = Variable<String>(imageTexture);
    }
    if (!nullToAbsent || grainLevel != null) {
      map['grain_level'] = Variable<String>(grainLevel);
    }
    if (!nullToAbsent || highlightBehavior != null) {
      map['highlight_behavior'] = Variable<String>(highlightBehavior);
    }
    if (!nullToAbsent || shadowBehavior != null) {
      map['shadow_behavior'] = Variable<String>(shadowBehavior);
    }
    if (!nullToAbsent || workingLutName != null) {
      map['working_lut_name'] = Variable<String>(workingLutName);
    }
    if (!nullToAbsent || creativeLutName != null) {
      map['creative_lut_name'] = Variable<String>(creativeLutName);
    }
    if (!nullToAbsent || creativeLutDescription != null) {
      map['creative_lut_description'] = Variable<String>(
        creativeLutDescription,
      );
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  VisualBiblesCompanion toCompanion(bool nullToAbsent) {
    return VisualBiblesCompanion(
      id: Value(id),
      projectId: Value(projectId),
      visualConcept: visualConcept == null && nullToAbsent
          ? const Value.absent()
          : Value(visualConcept),
      narrativeReferences: narrativeReferences == null && nullToAbsent
          ? const Value.absent()
          : Value(narrativeReferences),
      lightingPhilosophy: lightingPhilosophy == null && nullToAbsent
          ? const Value.absent()
          : Value(lightingPhilosophy),
      lightQuality: lightQuality == null && nullToAbsent
          ? const Value.absent()
          : Value(lightQuality),
      contrastStyle: contrastStyle == null && nullToAbsent
          ? const Value.absent()
          : Value(contrastStyle),
      keyFillRatioDay: keyFillRatioDay == null && nullToAbsent
          ? const Value.absent()
          : Value(keyFillRatioDay),
      keyFillRatioNight: keyFillRatioNight == null && nullToAbsent
          ? const Value.absent()
          : Value(keyFillRatioNight),
      lightSource: lightSource == null && nullToAbsent
          ? const Value.absent()
          : Value(lightSource),
      cameraPhilosophy: cameraPhilosophy == null && nullToAbsent
          ? const Value.absent()
          : Value(cameraPhilosophy),
      movementStyle: movementStyle == null && nullToAbsent
          ? const Value.absent()
          : Value(movementStyle),
      preferredMovements: preferredMovements == null && nullToAbsent
          ? const Value.absent()
          : Value(preferredMovements),
      lensPhilosophy: lensPhilosophy == null && nullToAbsent
          ? const Value.absent()
          : Value(lensPhilosophy),
      opticType: opticType == null && nullToAbsent
          ? const Value.absent()
          : Value(opticType),
      primaryFocalLengths: primaryFocalLengths == null && nullToAbsent
          ? const Value.absent()
          : Value(primaryFocalLengths),
      primaryLensId: primaryLensId == null && nullToAbsent
          ? const Value.absent()
          : Value(primaryLensId),
      aspectRatio: aspectRatio == null && nullToAbsent
          ? const Value.absent()
          : Value(aspectRatio),
      aspectRatioJustification: aspectRatioJustification == null && nullToAbsent
          ? const Value.absent()
          : Value(aspectRatioJustification),
      imageTexture: imageTexture == null && nullToAbsent
          ? const Value.absent()
          : Value(imageTexture),
      grainLevel: grainLevel == null && nullToAbsent
          ? const Value.absent()
          : Value(grainLevel),
      highlightBehavior: highlightBehavior == null && nullToAbsent
          ? const Value.absent()
          : Value(highlightBehavior),
      shadowBehavior: shadowBehavior == null && nullToAbsent
          ? const Value.absent()
          : Value(shadowBehavior),
      workingLutName: workingLutName == null && nullToAbsent
          ? const Value.absent()
          : Value(workingLutName),
      creativeLutName: creativeLutName == null && nullToAbsent
          ? const Value.absent()
          : Value(creativeLutName),
      creativeLutDescription: creativeLutDescription == null && nullToAbsent
          ? const Value.absent()
          : Value(creativeLutDescription),
      updatedAt: Value(updatedAt),
    );
  }

  factory VisualBible.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VisualBible(
      id: serializer.fromJson<int>(json['id']),
      projectId: serializer.fromJson<int>(json['projectId']),
      visualConcept: serializer.fromJson<String?>(json['visualConcept']),
      narrativeReferences: serializer.fromJson<String?>(
        json['narrativeReferences'],
      ),
      lightingPhilosophy: serializer.fromJson<String?>(
        json['lightingPhilosophy'],
      ),
      lightQuality: serializer.fromJson<String?>(json['lightQuality']),
      contrastStyle: serializer.fromJson<String?>(json['contrastStyle']),
      keyFillRatioDay: serializer.fromJson<String?>(json['keyFillRatioDay']),
      keyFillRatioNight: serializer.fromJson<String?>(
        json['keyFillRatioNight'],
      ),
      lightSource: serializer.fromJson<String?>(json['lightSource']),
      cameraPhilosophy: serializer.fromJson<String?>(json['cameraPhilosophy']),
      movementStyle: serializer.fromJson<String?>(json['movementStyle']),
      preferredMovements: serializer.fromJson<String?>(
        json['preferredMovements'],
      ),
      lensPhilosophy: serializer.fromJson<String?>(json['lensPhilosophy']),
      opticType: serializer.fromJson<String?>(json['opticType']),
      primaryFocalLengths: serializer.fromJson<String?>(
        json['primaryFocalLengths'],
      ),
      primaryLensId: serializer.fromJson<int?>(json['primaryLensId']),
      aspectRatio: serializer.fromJson<String?>(json['aspectRatio']),
      aspectRatioJustification: serializer.fromJson<String?>(
        json['aspectRatioJustification'],
      ),
      imageTexture: serializer.fromJson<String?>(json['imageTexture']),
      grainLevel: serializer.fromJson<String?>(json['grainLevel']),
      highlightBehavior: serializer.fromJson<String?>(
        json['highlightBehavior'],
      ),
      shadowBehavior: serializer.fromJson<String?>(json['shadowBehavior']),
      workingLutName: serializer.fromJson<String?>(json['workingLutName']),
      creativeLutName: serializer.fromJson<String?>(json['creativeLutName']),
      creativeLutDescription: serializer.fromJson<String?>(
        json['creativeLutDescription'],
      ),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'projectId': serializer.toJson<int>(projectId),
      'visualConcept': serializer.toJson<String?>(visualConcept),
      'narrativeReferences': serializer.toJson<String?>(narrativeReferences),
      'lightingPhilosophy': serializer.toJson<String?>(lightingPhilosophy),
      'lightQuality': serializer.toJson<String?>(lightQuality),
      'contrastStyle': serializer.toJson<String?>(contrastStyle),
      'keyFillRatioDay': serializer.toJson<String?>(keyFillRatioDay),
      'keyFillRatioNight': serializer.toJson<String?>(keyFillRatioNight),
      'lightSource': serializer.toJson<String?>(lightSource),
      'cameraPhilosophy': serializer.toJson<String?>(cameraPhilosophy),
      'movementStyle': serializer.toJson<String?>(movementStyle),
      'preferredMovements': serializer.toJson<String?>(preferredMovements),
      'lensPhilosophy': serializer.toJson<String?>(lensPhilosophy),
      'opticType': serializer.toJson<String?>(opticType),
      'primaryFocalLengths': serializer.toJson<String?>(primaryFocalLengths),
      'primaryLensId': serializer.toJson<int?>(primaryLensId),
      'aspectRatio': serializer.toJson<String?>(aspectRatio),
      'aspectRatioJustification': serializer.toJson<String?>(
        aspectRatioJustification,
      ),
      'imageTexture': serializer.toJson<String?>(imageTexture),
      'grainLevel': serializer.toJson<String?>(grainLevel),
      'highlightBehavior': serializer.toJson<String?>(highlightBehavior),
      'shadowBehavior': serializer.toJson<String?>(shadowBehavior),
      'workingLutName': serializer.toJson<String?>(workingLutName),
      'creativeLutName': serializer.toJson<String?>(creativeLutName),
      'creativeLutDescription': serializer.toJson<String?>(
        creativeLutDescription,
      ),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  VisualBible copyWith({
    int? id,
    int? projectId,
    Value<String?> visualConcept = const Value.absent(),
    Value<String?> narrativeReferences = const Value.absent(),
    Value<String?> lightingPhilosophy = const Value.absent(),
    Value<String?> lightQuality = const Value.absent(),
    Value<String?> contrastStyle = const Value.absent(),
    Value<String?> keyFillRatioDay = const Value.absent(),
    Value<String?> keyFillRatioNight = const Value.absent(),
    Value<String?> lightSource = const Value.absent(),
    Value<String?> cameraPhilosophy = const Value.absent(),
    Value<String?> movementStyle = const Value.absent(),
    Value<String?> preferredMovements = const Value.absent(),
    Value<String?> lensPhilosophy = const Value.absent(),
    Value<String?> opticType = const Value.absent(),
    Value<String?> primaryFocalLengths = const Value.absent(),
    Value<int?> primaryLensId = const Value.absent(),
    Value<String?> aspectRatio = const Value.absent(),
    Value<String?> aspectRatioJustification = const Value.absent(),
    Value<String?> imageTexture = const Value.absent(),
    Value<String?> grainLevel = const Value.absent(),
    Value<String?> highlightBehavior = const Value.absent(),
    Value<String?> shadowBehavior = const Value.absent(),
    Value<String?> workingLutName = const Value.absent(),
    Value<String?> creativeLutName = const Value.absent(),
    Value<String?> creativeLutDescription = const Value.absent(),
    DateTime? updatedAt,
  }) => VisualBible(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    visualConcept: visualConcept.present
        ? visualConcept.value
        : this.visualConcept,
    narrativeReferences: narrativeReferences.present
        ? narrativeReferences.value
        : this.narrativeReferences,
    lightingPhilosophy: lightingPhilosophy.present
        ? lightingPhilosophy.value
        : this.lightingPhilosophy,
    lightQuality: lightQuality.present ? lightQuality.value : this.lightQuality,
    contrastStyle: contrastStyle.present
        ? contrastStyle.value
        : this.contrastStyle,
    keyFillRatioDay: keyFillRatioDay.present
        ? keyFillRatioDay.value
        : this.keyFillRatioDay,
    keyFillRatioNight: keyFillRatioNight.present
        ? keyFillRatioNight.value
        : this.keyFillRatioNight,
    lightSource: lightSource.present ? lightSource.value : this.lightSource,
    cameraPhilosophy: cameraPhilosophy.present
        ? cameraPhilosophy.value
        : this.cameraPhilosophy,
    movementStyle: movementStyle.present
        ? movementStyle.value
        : this.movementStyle,
    preferredMovements: preferredMovements.present
        ? preferredMovements.value
        : this.preferredMovements,
    lensPhilosophy: lensPhilosophy.present
        ? lensPhilosophy.value
        : this.lensPhilosophy,
    opticType: opticType.present ? opticType.value : this.opticType,
    primaryFocalLengths: primaryFocalLengths.present
        ? primaryFocalLengths.value
        : this.primaryFocalLengths,
    primaryLensId: primaryLensId.present
        ? primaryLensId.value
        : this.primaryLensId,
    aspectRatio: aspectRatio.present ? aspectRatio.value : this.aspectRatio,
    aspectRatioJustification: aspectRatioJustification.present
        ? aspectRatioJustification.value
        : this.aspectRatioJustification,
    imageTexture: imageTexture.present ? imageTexture.value : this.imageTexture,
    grainLevel: grainLevel.present ? grainLevel.value : this.grainLevel,
    highlightBehavior: highlightBehavior.present
        ? highlightBehavior.value
        : this.highlightBehavior,
    shadowBehavior: shadowBehavior.present
        ? shadowBehavior.value
        : this.shadowBehavior,
    workingLutName: workingLutName.present
        ? workingLutName.value
        : this.workingLutName,
    creativeLutName: creativeLutName.present
        ? creativeLutName.value
        : this.creativeLutName,
    creativeLutDescription: creativeLutDescription.present
        ? creativeLutDescription.value
        : this.creativeLutDescription,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  VisualBible copyWithCompanion(VisualBiblesCompanion data) {
    return VisualBible(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      visualConcept: data.visualConcept.present
          ? data.visualConcept.value
          : this.visualConcept,
      narrativeReferences: data.narrativeReferences.present
          ? data.narrativeReferences.value
          : this.narrativeReferences,
      lightingPhilosophy: data.lightingPhilosophy.present
          ? data.lightingPhilosophy.value
          : this.lightingPhilosophy,
      lightQuality: data.lightQuality.present
          ? data.lightQuality.value
          : this.lightQuality,
      contrastStyle: data.contrastStyle.present
          ? data.contrastStyle.value
          : this.contrastStyle,
      keyFillRatioDay: data.keyFillRatioDay.present
          ? data.keyFillRatioDay.value
          : this.keyFillRatioDay,
      keyFillRatioNight: data.keyFillRatioNight.present
          ? data.keyFillRatioNight.value
          : this.keyFillRatioNight,
      lightSource: data.lightSource.present
          ? data.lightSource.value
          : this.lightSource,
      cameraPhilosophy: data.cameraPhilosophy.present
          ? data.cameraPhilosophy.value
          : this.cameraPhilosophy,
      movementStyle: data.movementStyle.present
          ? data.movementStyle.value
          : this.movementStyle,
      preferredMovements: data.preferredMovements.present
          ? data.preferredMovements.value
          : this.preferredMovements,
      lensPhilosophy: data.lensPhilosophy.present
          ? data.lensPhilosophy.value
          : this.lensPhilosophy,
      opticType: data.opticType.present ? data.opticType.value : this.opticType,
      primaryFocalLengths: data.primaryFocalLengths.present
          ? data.primaryFocalLengths.value
          : this.primaryFocalLengths,
      primaryLensId: data.primaryLensId.present
          ? data.primaryLensId.value
          : this.primaryLensId,
      aspectRatio: data.aspectRatio.present
          ? data.aspectRatio.value
          : this.aspectRatio,
      aspectRatioJustification: data.aspectRatioJustification.present
          ? data.aspectRatioJustification.value
          : this.aspectRatioJustification,
      imageTexture: data.imageTexture.present
          ? data.imageTexture.value
          : this.imageTexture,
      grainLevel: data.grainLevel.present
          ? data.grainLevel.value
          : this.grainLevel,
      highlightBehavior: data.highlightBehavior.present
          ? data.highlightBehavior.value
          : this.highlightBehavior,
      shadowBehavior: data.shadowBehavior.present
          ? data.shadowBehavior.value
          : this.shadowBehavior,
      workingLutName: data.workingLutName.present
          ? data.workingLutName.value
          : this.workingLutName,
      creativeLutName: data.creativeLutName.present
          ? data.creativeLutName.value
          : this.creativeLutName,
      creativeLutDescription: data.creativeLutDescription.present
          ? data.creativeLutDescription.value
          : this.creativeLutDescription,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VisualBible(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('visualConcept: $visualConcept, ')
          ..write('narrativeReferences: $narrativeReferences, ')
          ..write('lightingPhilosophy: $lightingPhilosophy, ')
          ..write('lightQuality: $lightQuality, ')
          ..write('contrastStyle: $contrastStyle, ')
          ..write('keyFillRatioDay: $keyFillRatioDay, ')
          ..write('keyFillRatioNight: $keyFillRatioNight, ')
          ..write('lightSource: $lightSource, ')
          ..write('cameraPhilosophy: $cameraPhilosophy, ')
          ..write('movementStyle: $movementStyle, ')
          ..write('preferredMovements: $preferredMovements, ')
          ..write('lensPhilosophy: $lensPhilosophy, ')
          ..write('opticType: $opticType, ')
          ..write('primaryFocalLengths: $primaryFocalLengths, ')
          ..write('primaryLensId: $primaryLensId, ')
          ..write('aspectRatio: $aspectRatio, ')
          ..write('aspectRatioJustification: $aspectRatioJustification, ')
          ..write('imageTexture: $imageTexture, ')
          ..write('grainLevel: $grainLevel, ')
          ..write('highlightBehavior: $highlightBehavior, ')
          ..write('shadowBehavior: $shadowBehavior, ')
          ..write('workingLutName: $workingLutName, ')
          ..write('creativeLutName: $creativeLutName, ')
          ..write('creativeLutDescription: $creativeLutDescription, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    projectId,
    visualConcept,
    narrativeReferences,
    lightingPhilosophy,
    lightQuality,
    contrastStyle,
    keyFillRatioDay,
    keyFillRatioNight,
    lightSource,
    cameraPhilosophy,
    movementStyle,
    preferredMovements,
    lensPhilosophy,
    opticType,
    primaryFocalLengths,
    primaryLensId,
    aspectRatio,
    aspectRatioJustification,
    imageTexture,
    grainLevel,
    highlightBehavior,
    shadowBehavior,
    workingLutName,
    creativeLutName,
    creativeLutDescription,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VisualBible &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.visualConcept == this.visualConcept &&
          other.narrativeReferences == this.narrativeReferences &&
          other.lightingPhilosophy == this.lightingPhilosophy &&
          other.lightQuality == this.lightQuality &&
          other.contrastStyle == this.contrastStyle &&
          other.keyFillRatioDay == this.keyFillRatioDay &&
          other.keyFillRatioNight == this.keyFillRatioNight &&
          other.lightSource == this.lightSource &&
          other.cameraPhilosophy == this.cameraPhilosophy &&
          other.movementStyle == this.movementStyle &&
          other.preferredMovements == this.preferredMovements &&
          other.lensPhilosophy == this.lensPhilosophy &&
          other.opticType == this.opticType &&
          other.primaryFocalLengths == this.primaryFocalLengths &&
          other.primaryLensId == this.primaryLensId &&
          other.aspectRatio == this.aspectRatio &&
          other.aspectRatioJustification == this.aspectRatioJustification &&
          other.imageTexture == this.imageTexture &&
          other.grainLevel == this.grainLevel &&
          other.highlightBehavior == this.highlightBehavior &&
          other.shadowBehavior == this.shadowBehavior &&
          other.workingLutName == this.workingLutName &&
          other.creativeLutName == this.creativeLutName &&
          other.creativeLutDescription == this.creativeLutDescription &&
          other.updatedAt == this.updatedAt);
}

class VisualBiblesCompanion extends UpdateCompanion<VisualBible> {
  final Value<int> id;
  final Value<int> projectId;
  final Value<String?> visualConcept;
  final Value<String?> narrativeReferences;
  final Value<String?> lightingPhilosophy;
  final Value<String?> lightQuality;
  final Value<String?> contrastStyle;
  final Value<String?> keyFillRatioDay;
  final Value<String?> keyFillRatioNight;
  final Value<String?> lightSource;
  final Value<String?> cameraPhilosophy;
  final Value<String?> movementStyle;
  final Value<String?> preferredMovements;
  final Value<String?> lensPhilosophy;
  final Value<String?> opticType;
  final Value<String?> primaryFocalLengths;
  final Value<int?> primaryLensId;
  final Value<String?> aspectRatio;
  final Value<String?> aspectRatioJustification;
  final Value<String?> imageTexture;
  final Value<String?> grainLevel;
  final Value<String?> highlightBehavior;
  final Value<String?> shadowBehavior;
  final Value<String?> workingLutName;
  final Value<String?> creativeLutName;
  final Value<String?> creativeLutDescription;
  final Value<DateTime> updatedAt;
  const VisualBiblesCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.visualConcept = const Value.absent(),
    this.narrativeReferences = const Value.absent(),
    this.lightingPhilosophy = const Value.absent(),
    this.lightQuality = const Value.absent(),
    this.contrastStyle = const Value.absent(),
    this.keyFillRatioDay = const Value.absent(),
    this.keyFillRatioNight = const Value.absent(),
    this.lightSource = const Value.absent(),
    this.cameraPhilosophy = const Value.absent(),
    this.movementStyle = const Value.absent(),
    this.preferredMovements = const Value.absent(),
    this.lensPhilosophy = const Value.absent(),
    this.opticType = const Value.absent(),
    this.primaryFocalLengths = const Value.absent(),
    this.primaryLensId = const Value.absent(),
    this.aspectRatio = const Value.absent(),
    this.aspectRatioJustification = const Value.absent(),
    this.imageTexture = const Value.absent(),
    this.grainLevel = const Value.absent(),
    this.highlightBehavior = const Value.absent(),
    this.shadowBehavior = const Value.absent(),
    this.workingLutName = const Value.absent(),
    this.creativeLutName = const Value.absent(),
    this.creativeLutDescription = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  VisualBiblesCompanion.insert({
    this.id = const Value.absent(),
    required int projectId,
    this.visualConcept = const Value.absent(),
    this.narrativeReferences = const Value.absent(),
    this.lightingPhilosophy = const Value.absent(),
    this.lightQuality = const Value.absent(),
    this.contrastStyle = const Value.absent(),
    this.keyFillRatioDay = const Value.absent(),
    this.keyFillRatioNight = const Value.absent(),
    this.lightSource = const Value.absent(),
    this.cameraPhilosophy = const Value.absent(),
    this.movementStyle = const Value.absent(),
    this.preferredMovements = const Value.absent(),
    this.lensPhilosophy = const Value.absent(),
    this.opticType = const Value.absent(),
    this.primaryFocalLengths = const Value.absent(),
    this.primaryLensId = const Value.absent(),
    this.aspectRatio = const Value.absent(),
    this.aspectRatioJustification = const Value.absent(),
    this.imageTexture = const Value.absent(),
    this.grainLevel = const Value.absent(),
    this.highlightBehavior = const Value.absent(),
    this.shadowBehavior = const Value.absent(),
    this.workingLutName = const Value.absent(),
    this.creativeLutName = const Value.absent(),
    this.creativeLutDescription = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : projectId = Value(projectId);
  static Insertable<VisualBible> custom({
    Expression<int>? id,
    Expression<int>? projectId,
    Expression<String>? visualConcept,
    Expression<String>? narrativeReferences,
    Expression<String>? lightingPhilosophy,
    Expression<String>? lightQuality,
    Expression<String>? contrastStyle,
    Expression<String>? keyFillRatioDay,
    Expression<String>? keyFillRatioNight,
    Expression<String>? lightSource,
    Expression<String>? cameraPhilosophy,
    Expression<String>? movementStyle,
    Expression<String>? preferredMovements,
    Expression<String>? lensPhilosophy,
    Expression<String>? opticType,
    Expression<String>? primaryFocalLengths,
    Expression<int>? primaryLensId,
    Expression<String>? aspectRatio,
    Expression<String>? aspectRatioJustification,
    Expression<String>? imageTexture,
    Expression<String>? grainLevel,
    Expression<String>? highlightBehavior,
    Expression<String>? shadowBehavior,
    Expression<String>? workingLutName,
    Expression<String>? creativeLutName,
    Expression<String>? creativeLutDescription,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (visualConcept != null) 'visual_concept': visualConcept,
      if (narrativeReferences != null)
        'narrative_references': narrativeReferences,
      if (lightingPhilosophy != null) 'lighting_philosophy': lightingPhilosophy,
      if (lightQuality != null) 'light_quality': lightQuality,
      if (contrastStyle != null) 'contrast_style': contrastStyle,
      if (keyFillRatioDay != null) 'key_fill_ratio_day': keyFillRatioDay,
      if (keyFillRatioNight != null) 'key_fill_ratio_night': keyFillRatioNight,
      if (lightSource != null) 'light_source': lightSource,
      if (cameraPhilosophy != null) 'camera_philosophy': cameraPhilosophy,
      if (movementStyle != null) 'movement_style': movementStyle,
      if (preferredMovements != null) 'preferred_movements': preferredMovements,
      if (lensPhilosophy != null) 'lens_philosophy': lensPhilosophy,
      if (opticType != null) 'optic_type': opticType,
      if (primaryFocalLengths != null)
        'primary_focal_lengths': primaryFocalLengths,
      if (primaryLensId != null) 'primary_lens_id': primaryLensId,
      if (aspectRatio != null) 'aspect_ratio': aspectRatio,
      if (aspectRatioJustification != null)
        'aspect_ratio_justification': aspectRatioJustification,
      if (imageTexture != null) 'image_texture': imageTexture,
      if (grainLevel != null) 'grain_level': grainLevel,
      if (highlightBehavior != null) 'highlight_behavior': highlightBehavior,
      if (shadowBehavior != null) 'shadow_behavior': shadowBehavior,
      if (workingLutName != null) 'working_lut_name': workingLutName,
      if (creativeLutName != null) 'creative_lut_name': creativeLutName,
      if (creativeLutDescription != null)
        'creative_lut_description': creativeLutDescription,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  VisualBiblesCompanion copyWith({
    Value<int>? id,
    Value<int>? projectId,
    Value<String?>? visualConcept,
    Value<String?>? narrativeReferences,
    Value<String?>? lightingPhilosophy,
    Value<String?>? lightQuality,
    Value<String?>? contrastStyle,
    Value<String?>? keyFillRatioDay,
    Value<String?>? keyFillRatioNight,
    Value<String?>? lightSource,
    Value<String?>? cameraPhilosophy,
    Value<String?>? movementStyle,
    Value<String?>? preferredMovements,
    Value<String?>? lensPhilosophy,
    Value<String?>? opticType,
    Value<String?>? primaryFocalLengths,
    Value<int?>? primaryLensId,
    Value<String?>? aspectRatio,
    Value<String?>? aspectRatioJustification,
    Value<String?>? imageTexture,
    Value<String?>? grainLevel,
    Value<String?>? highlightBehavior,
    Value<String?>? shadowBehavior,
    Value<String?>? workingLutName,
    Value<String?>? creativeLutName,
    Value<String?>? creativeLutDescription,
    Value<DateTime>? updatedAt,
  }) {
    return VisualBiblesCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      visualConcept: visualConcept ?? this.visualConcept,
      narrativeReferences: narrativeReferences ?? this.narrativeReferences,
      lightingPhilosophy: lightingPhilosophy ?? this.lightingPhilosophy,
      lightQuality: lightQuality ?? this.lightQuality,
      contrastStyle: contrastStyle ?? this.contrastStyle,
      keyFillRatioDay: keyFillRatioDay ?? this.keyFillRatioDay,
      keyFillRatioNight: keyFillRatioNight ?? this.keyFillRatioNight,
      lightSource: lightSource ?? this.lightSource,
      cameraPhilosophy: cameraPhilosophy ?? this.cameraPhilosophy,
      movementStyle: movementStyle ?? this.movementStyle,
      preferredMovements: preferredMovements ?? this.preferredMovements,
      lensPhilosophy: lensPhilosophy ?? this.lensPhilosophy,
      opticType: opticType ?? this.opticType,
      primaryFocalLengths: primaryFocalLengths ?? this.primaryFocalLengths,
      primaryLensId: primaryLensId ?? this.primaryLensId,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      aspectRatioJustification:
          aspectRatioJustification ?? this.aspectRatioJustification,
      imageTexture: imageTexture ?? this.imageTexture,
      grainLevel: grainLevel ?? this.grainLevel,
      highlightBehavior: highlightBehavior ?? this.highlightBehavior,
      shadowBehavior: shadowBehavior ?? this.shadowBehavior,
      workingLutName: workingLutName ?? this.workingLutName,
      creativeLutName: creativeLutName ?? this.creativeLutName,
      creativeLutDescription:
          creativeLutDescription ?? this.creativeLutDescription,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<int>(projectId.value);
    }
    if (visualConcept.present) {
      map['visual_concept'] = Variable<String>(visualConcept.value);
    }
    if (narrativeReferences.present) {
      map['narrative_references'] = Variable<String>(narrativeReferences.value);
    }
    if (lightingPhilosophy.present) {
      map['lighting_philosophy'] = Variable<String>(lightingPhilosophy.value);
    }
    if (lightQuality.present) {
      map['light_quality'] = Variable<String>(lightQuality.value);
    }
    if (contrastStyle.present) {
      map['contrast_style'] = Variable<String>(contrastStyle.value);
    }
    if (keyFillRatioDay.present) {
      map['key_fill_ratio_day'] = Variable<String>(keyFillRatioDay.value);
    }
    if (keyFillRatioNight.present) {
      map['key_fill_ratio_night'] = Variable<String>(keyFillRatioNight.value);
    }
    if (lightSource.present) {
      map['light_source'] = Variable<String>(lightSource.value);
    }
    if (cameraPhilosophy.present) {
      map['camera_philosophy'] = Variable<String>(cameraPhilosophy.value);
    }
    if (movementStyle.present) {
      map['movement_style'] = Variable<String>(movementStyle.value);
    }
    if (preferredMovements.present) {
      map['preferred_movements'] = Variable<String>(preferredMovements.value);
    }
    if (lensPhilosophy.present) {
      map['lens_philosophy'] = Variable<String>(lensPhilosophy.value);
    }
    if (opticType.present) {
      map['optic_type'] = Variable<String>(opticType.value);
    }
    if (primaryFocalLengths.present) {
      map['primary_focal_lengths'] = Variable<String>(
        primaryFocalLengths.value,
      );
    }
    if (primaryLensId.present) {
      map['primary_lens_id'] = Variable<int>(primaryLensId.value);
    }
    if (aspectRatio.present) {
      map['aspect_ratio'] = Variable<String>(aspectRatio.value);
    }
    if (aspectRatioJustification.present) {
      map['aspect_ratio_justification'] = Variable<String>(
        aspectRatioJustification.value,
      );
    }
    if (imageTexture.present) {
      map['image_texture'] = Variable<String>(imageTexture.value);
    }
    if (grainLevel.present) {
      map['grain_level'] = Variable<String>(grainLevel.value);
    }
    if (highlightBehavior.present) {
      map['highlight_behavior'] = Variable<String>(highlightBehavior.value);
    }
    if (shadowBehavior.present) {
      map['shadow_behavior'] = Variable<String>(shadowBehavior.value);
    }
    if (workingLutName.present) {
      map['working_lut_name'] = Variable<String>(workingLutName.value);
    }
    if (creativeLutName.present) {
      map['creative_lut_name'] = Variable<String>(creativeLutName.value);
    }
    if (creativeLutDescription.present) {
      map['creative_lut_description'] = Variable<String>(
        creativeLutDescription.value,
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VisualBiblesCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('visualConcept: $visualConcept, ')
          ..write('narrativeReferences: $narrativeReferences, ')
          ..write('lightingPhilosophy: $lightingPhilosophy, ')
          ..write('lightQuality: $lightQuality, ')
          ..write('contrastStyle: $contrastStyle, ')
          ..write('keyFillRatioDay: $keyFillRatioDay, ')
          ..write('keyFillRatioNight: $keyFillRatioNight, ')
          ..write('lightSource: $lightSource, ')
          ..write('cameraPhilosophy: $cameraPhilosophy, ')
          ..write('movementStyle: $movementStyle, ')
          ..write('preferredMovements: $preferredMovements, ')
          ..write('lensPhilosophy: $lensPhilosophy, ')
          ..write('opticType: $opticType, ')
          ..write('primaryFocalLengths: $primaryFocalLengths, ')
          ..write('primaryLensId: $primaryLensId, ')
          ..write('aspectRatio: $aspectRatio, ')
          ..write('aspectRatioJustification: $aspectRatioJustification, ')
          ..write('imageTexture: $imageTexture, ')
          ..write('grainLevel: $grainLevel, ')
          ..write('highlightBehavior: $highlightBehavior, ')
          ..write('shadowBehavior: $shadowBehavior, ')
          ..write('workingLutName: $workingLutName, ')
          ..write('creativeLutName: $creativeLutName, ')
          ..write('creativeLutDescription: $creativeLutDescription, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $VisualBibleColorBlocksTable extends VisualBibleColorBlocks
    with TableInfo<$VisualBibleColorBlocksTable, VisualBibleColorBlock> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VisualBibleColorBlocksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _bibleIdMeta = const VerificationMeta(
    'bibleId',
  );
  @override
  late final GeneratedColumn<int> bibleId = GeneratedColumn<int>(
    'bible_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES visual_bibles (id)',
    ),
  );
  static const VerificationMeta _blockNameMeta = const VerificationMeta(
    'blockName',
  );
  @override
  late final GeneratedColumn<String> blockName = GeneratedColumn<String>(
    'block_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emotionalIntentMeta = const VerificationMeta(
    'emotionalIntent',
  );
  @override
  late final GeneratedColumn<String> emotionalIntent = GeneratedColumn<String>(
    'emotional_intent',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dominantColorsMeta = const VerificationMeta(
    'dominantColors',
  );
  @override
  late final GeneratedColumn<String> dominantColors = GeneratedColumn<String>(
    'dominant_colors',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accentColorsMeta = const VerificationMeta(
    'accentColors',
  );
  @override
  late final GeneratedColumn<String> accentColors = GeneratedColumn<String>(
    'accent_colors',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _prohibitedColorsMeta = const VerificationMeta(
    'prohibitedColors',
  );
  @override
  late final GeneratedColumn<String> prohibitedColors = GeneratedColumn<String>(
    'prohibited_colors',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorTempKelvinMeta = const VerificationMeta(
    'colorTempKelvin',
  );
  @override
  late final GeneratedColumn<int> colorTempKelvin = GeneratedColumn<int>(
    'color_temp_kelvin',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _referenceImagesMeta = const VerificationMeta(
    'referenceImages',
  );
  @override
  late final GeneratedColumn<String> referenceImages = GeneratedColumn<String>(
    'reference_images',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bibleId,
    blockName,
    emotionalIntent,
    dominantColors,
    accentColors,
    prohibitedColors,
    colorTempKelvin,
    referenceImages,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'visual_bible_color_blocks';
  @override
  VerificationContext validateIntegrity(
    Insertable<VisualBibleColorBlock> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('bible_id')) {
      context.handle(
        _bibleIdMeta,
        bibleId.isAcceptableOrUnknown(data['bible_id']!, _bibleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bibleIdMeta);
    }
    if (data.containsKey('block_name')) {
      context.handle(
        _blockNameMeta,
        blockName.isAcceptableOrUnknown(data['block_name']!, _blockNameMeta),
      );
    } else if (isInserting) {
      context.missing(_blockNameMeta);
    }
    if (data.containsKey('emotional_intent')) {
      context.handle(
        _emotionalIntentMeta,
        emotionalIntent.isAcceptableOrUnknown(
          data['emotional_intent']!,
          _emotionalIntentMeta,
        ),
      );
    }
    if (data.containsKey('dominant_colors')) {
      context.handle(
        _dominantColorsMeta,
        dominantColors.isAcceptableOrUnknown(
          data['dominant_colors']!,
          _dominantColorsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dominantColorsMeta);
    }
    if (data.containsKey('accent_colors')) {
      context.handle(
        _accentColorsMeta,
        accentColors.isAcceptableOrUnknown(
          data['accent_colors']!,
          _accentColorsMeta,
        ),
      );
    }
    if (data.containsKey('prohibited_colors')) {
      context.handle(
        _prohibitedColorsMeta,
        prohibitedColors.isAcceptableOrUnknown(
          data['prohibited_colors']!,
          _prohibitedColorsMeta,
        ),
      );
    }
    if (data.containsKey('color_temp_kelvin')) {
      context.handle(
        _colorTempKelvinMeta,
        colorTempKelvin.isAcceptableOrUnknown(
          data['color_temp_kelvin']!,
          _colorTempKelvinMeta,
        ),
      );
    }
    if (data.containsKey('reference_images')) {
      context.handle(
        _referenceImagesMeta,
        referenceImages.isAcceptableOrUnknown(
          data['reference_images']!,
          _referenceImagesMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VisualBibleColorBlock map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VisualBibleColorBlock(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      bibleId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bible_id'],
      )!,
      blockName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}block_name'],
      )!,
      emotionalIntent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}emotional_intent'],
      ),
      dominantColors: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dominant_colors'],
      )!,
      accentColors: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}accent_colors'],
      ),
      prohibitedColors: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prohibited_colors'],
      ),
      colorTempKelvin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_temp_kelvin'],
      ),
      referenceImages: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference_images'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $VisualBibleColorBlocksTable createAlias(String alias) {
    return $VisualBibleColorBlocksTable(attachedDatabase, alias);
  }
}

class VisualBibleColorBlock extends DataClass
    implements Insertable<VisualBibleColorBlock> {
  final int id;
  final int bibleId;
  final String blockName;
  final String? emotionalIntent;
  final String dominantColors;
  final String? accentColors;
  final String? prohibitedColors;
  final int? colorTempKelvin;
  final String? referenceImages;
  final int sortOrder;
  const VisualBibleColorBlock({
    required this.id,
    required this.bibleId,
    required this.blockName,
    this.emotionalIntent,
    required this.dominantColors,
    this.accentColors,
    this.prohibitedColors,
    this.colorTempKelvin,
    this.referenceImages,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['bible_id'] = Variable<int>(bibleId);
    map['block_name'] = Variable<String>(blockName);
    if (!nullToAbsent || emotionalIntent != null) {
      map['emotional_intent'] = Variable<String>(emotionalIntent);
    }
    map['dominant_colors'] = Variable<String>(dominantColors);
    if (!nullToAbsent || accentColors != null) {
      map['accent_colors'] = Variable<String>(accentColors);
    }
    if (!nullToAbsent || prohibitedColors != null) {
      map['prohibited_colors'] = Variable<String>(prohibitedColors);
    }
    if (!nullToAbsent || colorTempKelvin != null) {
      map['color_temp_kelvin'] = Variable<int>(colorTempKelvin);
    }
    if (!nullToAbsent || referenceImages != null) {
      map['reference_images'] = Variable<String>(referenceImages);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  VisualBibleColorBlocksCompanion toCompanion(bool nullToAbsent) {
    return VisualBibleColorBlocksCompanion(
      id: Value(id),
      bibleId: Value(bibleId),
      blockName: Value(blockName),
      emotionalIntent: emotionalIntent == null && nullToAbsent
          ? const Value.absent()
          : Value(emotionalIntent),
      dominantColors: Value(dominantColors),
      accentColors: accentColors == null && nullToAbsent
          ? const Value.absent()
          : Value(accentColors),
      prohibitedColors: prohibitedColors == null && nullToAbsent
          ? const Value.absent()
          : Value(prohibitedColors),
      colorTempKelvin: colorTempKelvin == null && nullToAbsent
          ? const Value.absent()
          : Value(colorTempKelvin),
      referenceImages: referenceImages == null && nullToAbsent
          ? const Value.absent()
          : Value(referenceImages),
      sortOrder: Value(sortOrder),
    );
  }

  factory VisualBibleColorBlock.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VisualBibleColorBlock(
      id: serializer.fromJson<int>(json['id']),
      bibleId: serializer.fromJson<int>(json['bibleId']),
      blockName: serializer.fromJson<String>(json['blockName']),
      emotionalIntent: serializer.fromJson<String?>(json['emotionalIntent']),
      dominantColors: serializer.fromJson<String>(json['dominantColors']),
      accentColors: serializer.fromJson<String?>(json['accentColors']),
      prohibitedColors: serializer.fromJson<String?>(json['prohibitedColors']),
      colorTempKelvin: serializer.fromJson<int?>(json['colorTempKelvin']),
      referenceImages: serializer.fromJson<String?>(json['referenceImages']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bibleId': serializer.toJson<int>(bibleId),
      'blockName': serializer.toJson<String>(blockName),
      'emotionalIntent': serializer.toJson<String?>(emotionalIntent),
      'dominantColors': serializer.toJson<String>(dominantColors),
      'accentColors': serializer.toJson<String?>(accentColors),
      'prohibitedColors': serializer.toJson<String?>(prohibitedColors),
      'colorTempKelvin': serializer.toJson<int?>(colorTempKelvin),
      'referenceImages': serializer.toJson<String?>(referenceImages),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  VisualBibleColorBlock copyWith({
    int? id,
    int? bibleId,
    String? blockName,
    Value<String?> emotionalIntent = const Value.absent(),
    String? dominantColors,
    Value<String?> accentColors = const Value.absent(),
    Value<String?> prohibitedColors = const Value.absent(),
    Value<int?> colorTempKelvin = const Value.absent(),
    Value<String?> referenceImages = const Value.absent(),
    int? sortOrder,
  }) => VisualBibleColorBlock(
    id: id ?? this.id,
    bibleId: bibleId ?? this.bibleId,
    blockName: blockName ?? this.blockName,
    emotionalIntent: emotionalIntent.present
        ? emotionalIntent.value
        : this.emotionalIntent,
    dominantColors: dominantColors ?? this.dominantColors,
    accentColors: accentColors.present ? accentColors.value : this.accentColors,
    prohibitedColors: prohibitedColors.present
        ? prohibitedColors.value
        : this.prohibitedColors,
    colorTempKelvin: colorTempKelvin.present
        ? colorTempKelvin.value
        : this.colorTempKelvin,
    referenceImages: referenceImages.present
        ? referenceImages.value
        : this.referenceImages,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  VisualBibleColorBlock copyWithCompanion(
    VisualBibleColorBlocksCompanion data,
  ) {
    return VisualBibleColorBlock(
      id: data.id.present ? data.id.value : this.id,
      bibleId: data.bibleId.present ? data.bibleId.value : this.bibleId,
      blockName: data.blockName.present ? data.blockName.value : this.blockName,
      emotionalIntent: data.emotionalIntent.present
          ? data.emotionalIntent.value
          : this.emotionalIntent,
      dominantColors: data.dominantColors.present
          ? data.dominantColors.value
          : this.dominantColors,
      accentColors: data.accentColors.present
          ? data.accentColors.value
          : this.accentColors,
      prohibitedColors: data.prohibitedColors.present
          ? data.prohibitedColors.value
          : this.prohibitedColors,
      colorTempKelvin: data.colorTempKelvin.present
          ? data.colorTempKelvin.value
          : this.colorTempKelvin,
      referenceImages: data.referenceImages.present
          ? data.referenceImages.value
          : this.referenceImages,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VisualBibleColorBlock(')
          ..write('id: $id, ')
          ..write('bibleId: $bibleId, ')
          ..write('blockName: $blockName, ')
          ..write('emotionalIntent: $emotionalIntent, ')
          ..write('dominantColors: $dominantColors, ')
          ..write('accentColors: $accentColors, ')
          ..write('prohibitedColors: $prohibitedColors, ')
          ..write('colorTempKelvin: $colorTempKelvin, ')
          ..write('referenceImages: $referenceImages, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bibleId,
    blockName,
    emotionalIntent,
    dominantColors,
    accentColors,
    prohibitedColors,
    colorTempKelvin,
    referenceImages,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VisualBibleColorBlock &&
          other.id == this.id &&
          other.bibleId == this.bibleId &&
          other.blockName == this.blockName &&
          other.emotionalIntent == this.emotionalIntent &&
          other.dominantColors == this.dominantColors &&
          other.accentColors == this.accentColors &&
          other.prohibitedColors == this.prohibitedColors &&
          other.colorTempKelvin == this.colorTempKelvin &&
          other.referenceImages == this.referenceImages &&
          other.sortOrder == this.sortOrder);
}

class VisualBibleColorBlocksCompanion
    extends UpdateCompanion<VisualBibleColorBlock> {
  final Value<int> id;
  final Value<int> bibleId;
  final Value<String> blockName;
  final Value<String?> emotionalIntent;
  final Value<String> dominantColors;
  final Value<String?> accentColors;
  final Value<String?> prohibitedColors;
  final Value<int?> colorTempKelvin;
  final Value<String?> referenceImages;
  final Value<int> sortOrder;
  const VisualBibleColorBlocksCompanion({
    this.id = const Value.absent(),
    this.bibleId = const Value.absent(),
    this.blockName = const Value.absent(),
    this.emotionalIntent = const Value.absent(),
    this.dominantColors = const Value.absent(),
    this.accentColors = const Value.absent(),
    this.prohibitedColors = const Value.absent(),
    this.colorTempKelvin = const Value.absent(),
    this.referenceImages = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  VisualBibleColorBlocksCompanion.insert({
    this.id = const Value.absent(),
    required int bibleId,
    required String blockName,
    this.emotionalIntent = const Value.absent(),
    required String dominantColors,
    this.accentColors = const Value.absent(),
    this.prohibitedColors = const Value.absent(),
    this.colorTempKelvin = const Value.absent(),
    this.referenceImages = const Value.absent(),
    this.sortOrder = const Value.absent(),
  }) : bibleId = Value(bibleId),
       blockName = Value(blockName),
       dominantColors = Value(dominantColors);
  static Insertable<VisualBibleColorBlock> custom({
    Expression<int>? id,
    Expression<int>? bibleId,
    Expression<String>? blockName,
    Expression<String>? emotionalIntent,
    Expression<String>? dominantColors,
    Expression<String>? accentColors,
    Expression<String>? prohibitedColors,
    Expression<int>? colorTempKelvin,
    Expression<String>? referenceImages,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bibleId != null) 'bible_id': bibleId,
      if (blockName != null) 'block_name': blockName,
      if (emotionalIntent != null) 'emotional_intent': emotionalIntent,
      if (dominantColors != null) 'dominant_colors': dominantColors,
      if (accentColors != null) 'accent_colors': accentColors,
      if (prohibitedColors != null) 'prohibited_colors': prohibitedColors,
      if (colorTempKelvin != null) 'color_temp_kelvin': colorTempKelvin,
      if (referenceImages != null) 'reference_images': referenceImages,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  VisualBibleColorBlocksCompanion copyWith({
    Value<int>? id,
    Value<int>? bibleId,
    Value<String>? blockName,
    Value<String?>? emotionalIntent,
    Value<String>? dominantColors,
    Value<String?>? accentColors,
    Value<String?>? prohibitedColors,
    Value<int?>? colorTempKelvin,
    Value<String?>? referenceImages,
    Value<int>? sortOrder,
  }) {
    return VisualBibleColorBlocksCompanion(
      id: id ?? this.id,
      bibleId: bibleId ?? this.bibleId,
      blockName: blockName ?? this.blockName,
      emotionalIntent: emotionalIntent ?? this.emotionalIntent,
      dominantColors: dominantColors ?? this.dominantColors,
      accentColors: accentColors ?? this.accentColors,
      prohibitedColors: prohibitedColors ?? this.prohibitedColors,
      colorTempKelvin: colorTempKelvin ?? this.colorTempKelvin,
      referenceImages: referenceImages ?? this.referenceImages,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bibleId.present) {
      map['bible_id'] = Variable<int>(bibleId.value);
    }
    if (blockName.present) {
      map['block_name'] = Variable<String>(blockName.value);
    }
    if (emotionalIntent.present) {
      map['emotional_intent'] = Variable<String>(emotionalIntent.value);
    }
    if (dominantColors.present) {
      map['dominant_colors'] = Variable<String>(dominantColors.value);
    }
    if (accentColors.present) {
      map['accent_colors'] = Variable<String>(accentColors.value);
    }
    if (prohibitedColors.present) {
      map['prohibited_colors'] = Variable<String>(prohibitedColors.value);
    }
    if (colorTempKelvin.present) {
      map['color_temp_kelvin'] = Variable<int>(colorTempKelvin.value);
    }
    if (referenceImages.present) {
      map['reference_images'] = Variable<String>(referenceImages.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VisualBibleColorBlocksCompanion(')
          ..write('id: $id, ')
          ..write('bibleId: $bibleId, ')
          ..write('blockName: $blockName, ')
          ..write('emotionalIntent: $emotionalIntent, ')
          ..write('dominantColors: $dominantColors, ')
          ..write('accentColors: $accentColors, ')
          ..write('prohibitedColors: $prohibitedColors, ')
          ..write('colorTempKelvin: $colorTempKelvin, ')
          ..write('referenceImages: $referenceImages, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }
}

class $VisualBibleLocationRefsTable extends VisualBibleLocationRefs
    with TableInfo<$VisualBibleLocationRefsTable, VisualBibleLocationRef> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VisualBibleLocationRefsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _bibleIdMeta = const VerificationMeta(
    'bibleId',
  );
  @override
  late final GeneratedColumn<int> bibleId = GeneratedColumn<int>(
    'bible_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES visual_bibles (id)',
    ),
  );
  static const VerificationMeta _locationNameMeta = const VerificationMeta(
    'locationName',
  );
  @override
  late final GeneratedColumn<String> locationName = GeneratedColumn<String>(
    'location_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lightingNoteMeta = const VerificationMeta(
    'lightingNote',
  );
  @override
  late final GeneratedColumn<String> lightingNote = GeneratedColumn<String>(
    'lighting_note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorNoteMeta = const VerificationMeta(
    'colorNote',
  );
  @override
  late final GeneratedColumn<String> colorNote = GeneratedColumn<String>(
    'color_note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _referenceImagesMeta = const VerificationMeta(
    'referenceImages',
  );
  @override
  late final GeneratedColumn<String> referenceImages = GeneratedColumn<String>(
    'reference_images',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _linkedShotIdsMeta = const VerificationMeta(
    'linkedShotIds',
  );
  @override
  late final GeneratedColumn<String> linkedShotIds = GeneratedColumn<String>(
    'linked_shot_ids',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bibleId,
    locationName,
    lightingNote,
    colorNote,
    referenceImages,
    linkedShotIds,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'visual_bible_location_refs';
  @override
  VerificationContext validateIntegrity(
    Insertable<VisualBibleLocationRef> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('bible_id')) {
      context.handle(
        _bibleIdMeta,
        bibleId.isAcceptableOrUnknown(data['bible_id']!, _bibleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bibleIdMeta);
    }
    if (data.containsKey('location_name')) {
      context.handle(
        _locationNameMeta,
        locationName.isAcceptableOrUnknown(
          data['location_name']!,
          _locationNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_locationNameMeta);
    }
    if (data.containsKey('lighting_note')) {
      context.handle(
        _lightingNoteMeta,
        lightingNote.isAcceptableOrUnknown(
          data['lighting_note']!,
          _lightingNoteMeta,
        ),
      );
    }
    if (data.containsKey('color_note')) {
      context.handle(
        _colorNoteMeta,
        colorNote.isAcceptableOrUnknown(data['color_note']!, _colorNoteMeta),
      );
    }
    if (data.containsKey('reference_images')) {
      context.handle(
        _referenceImagesMeta,
        referenceImages.isAcceptableOrUnknown(
          data['reference_images']!,
          _referenceImagesMeta,
        ),
      );
    }
    if (data.containsKey('linked_shot_ids')) {
      context.handle(
        _linkedShotIdsMeta,
        linkedShotIds.isAcceptableOrUnknown(
          data['linked_shot_ids']!,
          _linkedShotIdsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VisualBibleLocationRef map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VisualBibleLocationRef(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      bibleId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bible_id'],
      )!,
      locationName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location_name'],
      )!,
      lightingNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lighting_note'],
      ),
      colorNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_note'],
      ),
      referenceImages: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference_images'],
      ),
      linkedShotIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}linked_shot_ids'],
      ),
    );
  }

  @override
  $VisualBibleLocationRefsTable createAlias(String alias) {
    return $VisualBibleLocationRefsTable(attachedDatabase, alias);
  }
}

class VisualBibleLocationRef extends DataClass
    implements Insertable<VisualBibleLocationRef> {
  final int id;
  final int bibleId;
  final String locationName;
  final String? lightingNote;
  final String? colorNote;
  final String? referenceImages;
  final String? linkedShotIds;
  const VisualBibleLocationRef({
    required this.id,
    required this.bibleId,
    required this.locationName,
    this.lightingNote,
    this.colorNote,
    this.referenceImages,
    this.linkedShotIds,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['bible_id'] = Variable<int>(bibleId);
    map['location_name'] = Variable<String>(locationName);
    if (!nullToAbsent || lightingNote != null) {
      map['lighting_note'] = Variable<String>(lightingNote);
    }
    if (!nullToAbsent || colorNote != null) {
      map['color_note'] = Variable<String>(colorNote);
    }
    if (!nullToAbsent || referenceImages != null) {
      map['reference_images'] = Variable<String>(referenceImages);
    }
    if (!nullToAbsent || linkedShotIds != null) {
      map['linked_shot_ids'] = Variable<String>(linkedShotIds);
    }
    return map;
  }

  VisualBibleLocationRefsCompanion toCompanion(bool nullToAbsent) {
    return VisualBibleLocationRefsCompanion(
      id: Value(id),
      bibleId: Value(bibleId),
      locationName: Value(locationName),
      lightingNote: lightingNote == null && nullToAbsent
          ? const Value.absent()
          : Value(lightingNote),
      colorNote: colorNote == null && nullToAbsent
          ? const Value.absent()
          : Value(colorNote),
      referenceImages: referenceImages == null && nullToAbsent
          ? const Value.absent()
          : Value(referenceImages),
      linkedShotIds: linkedShotIds == null && nullToAbsent
          ? const Value.absent()
          : Value(linkedShotIds),
    );
  }

  factory VisualBibleLocationRef.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VisualBibleLocationRef(
      id: serializer.fromJson<int>(json['id']),
      bibleId: serializer.fromJson<int>(json['bibleId']),
      locationName: serializer.fromJson<String>(json['locationName']),
      lightingNote: serializer.fromJson<String?>(json['lightingNote']),
      colorNote: serializer.fromJson<String?>(json['colorNote']),
      referenceImages: serializer.fromJson<String?>(json['referenceImages']),
      linkedShotIds: serializer.fromJson<String?>(json['linkedShotIds']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bibleId': serializer.toJson<int>(bibleId),
      'locationName': serializer.toJson<String>(locationName),
      'lightingNote': serializer.toJson<String?>(lightingNote),
      'colorNote': serializer.toJson<String?>(colorNote),
      'referenceImages': serializer.toJson<String?>(referenceImages),
      'linkedShotIds': serializer.toJson<String?>(linkedShotIds),
    };
  }

  VisualBibleLocationRef copyWith({
    int? id,
    int? bibleId,
    String? locationName,
    Value<String?> lightingNote = const Value.absent(),
    Value<String?> colorNote = const Value.absent(),
    Value<String?> referenceImages = const Value.absent(),
    Value<String?> linkedShotIds = const Value.absent(),
  }) => VisualBibleLocationRef(
    id: id ?? this.id,
    bibleId: bibleId ?? this.bibleId,
    locationName: locationName ?? this.locationName,
    lightingNote: lightingNote.present ? lightingNote.value : this.lightingNote,
    colorNote: colorNote.present ? colorNote.value : this.colorNote,
    referenceImages: referenceImages.present
        ? referenceImages.value
        : this.referenceImages,
    linkedShotIds: linkedShotIds.present
        ? linkedShotIds.value
        : this.linkedShotIds,
  );
  VisualBibleLocationRef copyWithCompanion(
    VisualBibleLocationRefsCompanion data,
  ) {
    return VisualBibleLocationRef(
      id: data.id.present ? data.id.value : this.id,
      bibleId: data.bibleId.present ? data.bibleId.value : this.bibleId,
      locationName: data.locationName.present
          ? data.locationName.value
          : this.locationName,
      lightingNote: data.lightingNote.present
          ? data.lightingNote.value
          : this.lightingNote,
      colorNote: data.colorNote.present ? data.colorNote.value : this.colorNote,
      referenceImages: data.referenceImages.present
          ? data.referenceImages.value
          : this.referenceImages,
      linkedShotIds: data.linkedShotIds.present
          ? data.linkedShotIds.value
          : this.linkedShotIds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VisualBibleLocationRef(')
          ..write('id: $id, ')
          ..write('bibleId: $bibleId, ')
          ..write('locationName: $locationName, ')
          ..write('lightingNote: $lightingNote, ')
          ..write('colorNote: $colorNote, ')
          ..write('referenceImages: $referenceImages, ')
          ..write('linkedShotIds: $linkedShotIds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bibleId,
    locationName,
    lightingNote,
    colorNote,
    referenceImages,
    linkedShotIds,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VisualBibleLocationRef &&
          other.id == this.id &&
          other.bibleId == this.bibleId &&
          other.locationName == this.locationName &&
          other.lightingNote == this.lightingNote &&
          other.colorNote == this.colorNote &&
          other.referenceImages == this.referenceImages &&
          other.linkedShotIds == this.linkedShotIds);
}

class VisualBibleLocationRefsCompanion
    extends UpdateCompanion<VisualBibleLocationRef> {
  final Value<int> id;
  final Value<int> bibleId;
  final Value<String> locationName;
  final Value<String?> lightingNote;
  final Value<String?> colorNote;
  final Value<String?> referenceImages;
  final Value<String?> linkedShotIds;
  const VisualBibleLocationRefsCompanion({
    this.id = const Value.absent(),
    this.bibleId = const Value.absent(),
    this.locationName = const Value.absent(),
    this.lightingNote = const Value.absent(),
    this.colorNote = const Value.absent(),
    this.referenceImages = const Value.absent(),
    this.linkedShotIds = const Value.absent(),
  });
  VisualBibleLocationRefsCompanion.insert({
    this.id = const Value.absent(),
    required int bibleId,
    required String locationName,
    this.lightingNote = const Value.absent(),
    this.colorNote = const Value.absent(),
    this.referenceImages = const Value.absent(),
    this.linkedShotIds = const Value.absent(),
  }) : bibleId = Value(bibleId),
       locationName = Value(locationName);
  static Insertable<VisualBibleLocationRef> custom({
    Expression<int>? id,
    Expression<int>? bibleId,
    Expression<String>? locationName,
    Expression<String>? lightingNote,
    Expression<String>? colorNote,
    Expression<String>? referenceImages,
    Expression<String>? linkedShotIds,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bibleId != null) 'bible_id': bibleId,
      if (locationName != null) 'location_name': locationName,
      if (lightingNote != null) 'lighting_note': lightingNote,
      if (colorNote != null) 'color_note': colorNote,
      if (referenceImages != null) 'reference_images': referenceImages,
      if (linkedShotIds != null) 'linked_shot_ids': linkedShotIds,
    });
  }

  VisualBibleLocationRefsCompanion copyWith({
    Value<int>? id,
    Value<int>? bibleId,
    Value<String>? locationName,
    Value<String?>? lightingNote,
    Value<String?>? colorNote,
    Value<String?>? referenceImages,
    Value<String?>? linkedShotIds,
  }) {
    return VisualBibleLocationRefsCompanion(
      id: id ?? this.id,
      bibleId: bibleId ?? this.bibleId,
      locationName: locationName ?? this.locationName,
      lightingNote: lightingNote ?? this.lightingNote,
      colorNote: colorNote ?? this.colorNote,
      referenceImages: referenceImages ?? this.referenceImages,
      linkedShotIds: linkedShotIds ?? this.linkedShotIds,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bibleId.present) {
      map['bible_id'] = Variable<int>(bibleId.value);
    }
    if (locationName.present) {
      map['location_name'] = Variable<String>(locationName.value);
    }
    if (lightingNote.present) {
      map['lighting_note'] = Variable<String>(lightingNote.value);
    }
    if (colorNote.present) {
      map['color_note'] = Variable<String>(colorNote.value);
    }
    if (referenceImages.present) {
      map['reference_images'] = Variable<String>(referenceImages.value);
    }
    if (linkedShotIds.present) {
      map['linked_shot_ids'] = Variable<String>(linkedShotIds.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VisualBibleLocationRefsCompanion(')
          ..write('id: $id, ')
          ..write('bibleId: $bibleId, ')
          ..write('locationName: $locationName, ')
          ..write('lightingNote: $lightingNote, ')
          ..write('colorNote: $colorNote, ')
          ..write('referenceImages: $referenceImages, ')
          ..write('linkedShotIds: $linkedShotIds')
          ..write(')'))
        .toString();
  }
}

class $MoodboardImagesTable extends MoodboardImages
    with TableInfo<$MoodboardImagesTable, MoodboardImage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MoodboardImagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<int> projectId = GeneratedColumn<int>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id)',
    ),
  );
  static const VerificationMeta _bibleIdMeta = const VerificationMeta(
    'bibleId',
  );
  @override
  late final GeneratedColumn<int> bibleId = GeneratedColumn<int>(
    'bible_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES visual_bibles (id)',
    ),
  );
  static const VerificationMeta _imagePathMeta = const VerificationMeta(
    'imagePath',
  );
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
    'image_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _captionMeta = const VerificationMeta(
    'caption',
  );
  @override
  late final GeneratedColumn<String> caption = GeneratedColumn<String>(
    'caption',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _filmReferenceMeta = const VerificationMeta(
    'filmReference',
  );
  @override
  late final GeneratedColumn<String> filmReference = GeneratedColumn<String>(
    'film_reference',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _linkedSceneIdMeta = const VerificationMeta(
    'linkedSceneId',
  );
  @override
  late final GeneratedColumn<int> linkedSceneId = GeneratedColumn<int>(
    'linked_scene_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _linkedLocationNameMeta =
      const VerificationMeta('linkedLocationName');
  @override
  late final GeneratedColumn<String> linkedLocationName =
      GeneratedColumn<String>(
        'linked_location_name',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    bibleId,
    imagePath,
    source,
    category,
    caption,
    filmReference,
    linkedSceneId,
    linkedLocationName,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'moodboard_images';
  @override
  VerificationContext validateIntegrity(
    Insertable<MoodboardImage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('bible_id')) {
      context.handle(
        _bibleIdMeta,
        bibleId.isAcceptableOrUnknown(data['bible_id']!, _bibleIdMeta),
      );
    }
    if (data.containsKey('image_path')) {
      context.handle(
        _imagePathMeta,
        imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta),
      );
    } else if (isInserting) {
      context.missing(_imagePathMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('caption')) {
      context.handle(
        _captionMeta,
        caption.isAcceptableOrUnknown(data['caption']!, _captionMeta),
      );
    }
    if (data.containsKey('film_reference')) {
      context.handle(
        _filmReferenceMeta,
        filmReference.isAcceptableOrUnknown(
          data['film_reference']!,
          _filmReferenceMeta,
        ),
      );
    }
    if (data.containsKey('linked_scene_id')) {
      context.handle(
        _linkedSceneIdMeta,
        linkedSceneId.isAcceptableOrUnknown(
          data['linked_scene_id']!,
          _linkedSceneIdMeta,
        ),
      );
    }
    if (data.containsKey('linked_location_name')) {
      context.handle(
        _linkedLocationNameMeta,
        linkedLocationName.isAcceptableOrUnknown(
          data['linked_location_name']!,
          _linkedLocationNameMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MoodboardImage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MoodboardImage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}project_id'],
      )!,
      bibleId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bible_id'],
      ),
      imagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_path'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      caption: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}caption'],
      ),
      filmReference: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}film_reference'],
      ),
      linkedSceneId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}linked_scene_id'],
      ),
      linkedLocationName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}linked_location_name'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $MoodboardImagesTable createAlias(String alias) {
    return $MoodboardImagesTable(attachedDatabase, alias);
  }
}

class MoodboardImage extends DataClass implements Insertable<MoodboardImage> {
  final int id;
  final int projectId;
  final int? bibleId;
  final String imagePath;
  final String source;
  final String? category;
  final String? caption;
  final String? filmReference;
  final int? linkedSceneId;
  final String? linkedLocationName;
  final int sortOrder;
  const MoodboardImage({
    required this.id,
    required this.projectId,
    this.bibleId,
    required this.imagePath,
    required this.source,
    this.category,
    this.caption,
    this.filmReference,
    this.linkedSceneId,
    this.linkedLocationName,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['project_id'] = Variable<int>(projectId);
    if (!nullToAbsent || bibleId != null) {
      map['bible_id'] = Variable<int>(bibleId);
    }
    map['image_path'] = Variable<String>(imagePath);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    if (!nullToAbsent || caption != null) {
      map['caption'] = Variable<String>(caption);
    }
    if (!nullToAbsent || filmReference != null) {
      map['film_reference'] = Variable<String>(filmReference);
    }
    if (!nullToAbsent || linkedSceneId != null) {
      map['linked_scene_id'] = Variable<int>(linkedSceneId);
    }
    if (!nullToAbsent || linkedLocationName != null) {
      map['linked_location_name'] = Variable<String>(linkedLocationName);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  MoodboardImagesCompanion toCompanion(bool nullToAbsent) {
    return MoodboardImagesCompanion(
      id: Value(id),
      projectId: Value(projectId),
      bibleId: bibleId == null && nullToAbsent
          ? const Value.absent()
          : Value(bibleId),
      imagePath: Value(imagePath),
      source: Value(source),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      caption: caption == null && nullToAbsent
          ? const Value.absent()
          : Value(caption),
      filmReference: filmReference == null && nullToAbsent
          ? const Value.absent()
          : Value(filmReference),
      linkedSceneId: linkedSceneId == null && nullToAbsent
          ? const Value.absent()
          : Value(linkedSceneId),
      linkedLocationName: linkedLocationName == null && nullToAbsent
          ? const Value.absent()
          : Value(linkedLocationName),
      sortOrder: Value(sortOrder),
    );
  }

  factory MoodboardImage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MoodboardImage(
      id: serializer.fromJson<int>(json['id']),
      projectId: serializer.fromJson<int>(json['projectId']),
      bibleId: serializer.fromJson<int?>(json['bibleId']),
      imagePath: serializer.fromJson<String>(json['imagePath']),
      source: serializer.fromJson<String>(json['source']),
      category: serializer.fromJson<String?>(json['category']),
      caption: serializer.fromJson<String?>(json['caption']),
      filmReference: serializer.fromJson<String?>(json['filmReference']),
      linkedSceneId: serializer.fromJson<int?>(json['linkedSceneId']),
      linkedLocationName: serializer.fromJson<String?>(
        json['linkedLocationName'],
      ),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'projectId': serializer.toJson<int>(projectId),
      'bibleId': serializer.toJson<int?>(bibleId),
      'imagePath': serializer.toJson<String>(imagePath),
      'source': serializer.toJson<String>(source),
      'category': serializer.toJson<String?>(category),
      'caption': serializer.toJson<String?>(caption),
      'filmReference': serializer.toJson<String?>(filmReference),
      'linkedSceneId': serializer.toJson<int?>(linkedSceneId),
      'linkedLocationName': serializer.toJson<String?>(linkedLocationName),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  MoodboardImage copyWith({
    int? id,
    int? projectId,
    Value<int?> bibleId = const Value.absent(),
    String? imagePath,
    String? source,
    Value<String?> category = const Value.absent(),
    Value<String?> caption = const Value.absent(),
    Value<String?> filmReference = const Value.absent(),
    Value<int?> linkedSceneId = const Value.absent(),
    Value<String?> linkedLocationName = const Value.absent(),
    int? sortOrder,
  }) => MoodboardImage(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    bibleId: bibleId.present ? bibleId.value : this.bibleId,
    imagePath: imagePath ?? this.imagePath,
    source: source ?? this.source,
    category: category.present ? category.value : this.category,
    caption: caption.present ? caption.value : this.caption,
    filmReference: filmReference.present
        ? filmReference.value
        : this.filmReference,
    linkedSceneId: linkedSceneId.present
        ? linkedSceneId.value
        : this.linkedSceneId,
    linkedLocationName: linkedLocationName.present
        ? linkedLocationName.value
        : this.linkedLocationName,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  MoodboardImage copyWithCompanion(MoodboardImagesCompanion data) {
    return MoodboardImage(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      bibleId: data.bibleId.present ? data.bibleId.value : this.bibleId,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      source: data.source.present ? data.source.value : this.source,
      category: data.category.present ? data.category.value : this.category,
      caption: data.caption.present ? data.caption.value : this.caption,
      filmReference: data.filmReference.present
          ? data.filmReference.value
          : this.filmReference,
      linkedSceneId: data.linkedSceneId.present
          ? data.linkedSceneId.value
          : this.linkedSceneId,
      linkedLocationName: data.linkedLocationName.present
          ? data.linkedLocationName.value
          : this.linkedLocationName,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MoodboardImage(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('bibleId: $bibleId, ')
          ..write('imagePath: $imagePath, ')
          ..write('source: $source, ')
          ..write('category: $category, ')
          ..write('caption: $caption, ')
          ..write('filmReference: $filmReference, ')
          ..write('linkedSceneId: $linkedSceneId, ')
          ..write('linkedLocationName: $linkedLocationName, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    bibleId,
    imagePath,
    source,
    category,
    caption,
    filmReference,
    linkedSceneId,
    linkedLocationName,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MoodboardImage &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.bibleId == this.bibleId &&
          other.imagePath == this.imagePath &&
          other.source == this.source &&
          other.category == this.category &&
          other.caption == this.caption &&
          other.filmReference == this.filmReference &&
          other.linkedSceneId == this.linkedSceneId &&
          other.linkedLocationName == this.linkedLocationName &&
          other.sortOrder == this.sortOrder);
}

class MoodboardImagesCompanion extends UpdateCompanion<MoodboardImage> {
  final Value<int> id;
  final Value<int> projectId;
  final Value<int?> bibleId;
  final Value<String> imagePath;
  final Value<String> source;
  final Value<String?> category;
  final Value<String?> caption;
  final Value<String?> filmReference;
  final Value<int?> linkedSceneId;
  final Value<String?> linkedLocationName;
  final Value<int> sortOrder;
  const MoodboardImagesCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.bibleId = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.source = const Value.absent(),
    this.category = const Value.absent(),
    this.caption = const Value.absent(),
    this.filmReference = const Value.absent(),
    this.linkedSceneId = const Value.absent(),
    this.linkedLocationName = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  MoodboardImagesCompanion.insert({
    this.id = const Value.absent(),
    required int projectId,
    this.bibleId = const Value.absent(),
    required String imagePath,
    this.source = const Value.absent(),
    this.category = const Value.absent(),
    this.caption = const Value.absent(),
    this.filmReference = const Value.absent(),
    this.linkedSceneId = const Value.absent(),
    this.linkedLocationName = const Value.absent(),
    this.sortOrder = const Value.absent(),
  }) : projectId = Value(projectId),
       imagePath = Value(imagePath);
  static Insertable<MoodboardImage> custom({
    Expression<int>? id,
    Expression<int>? projectId,
    Expression<int>? bibleId,
    Expression<String>? imagePath,
    Expression<String>? source,
    Expression<String>? category,
    Expression<String>? caption,
    Expression<String>? filmReference,
    Expression<int>? linkedSceneId,
    Expression<String>? linkedLocationName,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (bibleId != null) 'bible_id': bibleId,
      if (imagePath != null) 'image_path': imagePath,
      if (source != null) 'source': source,
      if (category != null) 'category': category,
      if (caption != null) 'caption': caption,
      if (filmReference != null) 'film_reference': filmReference,
      if (linkedSceneId != null) 'linked_scene_id': linkedSceneId,
      if (linkedLocationName != null)
        'linked_location_name': linkedLocationName,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  MoodboardImagesCompanion copyWith({
    Value<int>? id,
    Value<int>? projectId,
    Value<int?>? bibleId,
    Value<String>? imagePath,
    Value<String>? source,
    Value<String?>? category,
    Value<String?>? caption,
    Value<String?>? filmReference,
    Value<int?>? linkedSceneId,
    Value<String?>? linkedLocationName,
    Value<int>? sortOrder,
  }) {
    return MoodboardImagesCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      bibleId: bibleId ?? this.bibleId,
      imagePath: imagePath ?? this.imagePath,
      source: source ?? this.source,
      category: category ?? this.category,
      caption: caption ?? this.caption,
      filmReference: filmReference ?? this.filmReference,
      linkedSceneId: linkedSceneId ?? this.linkedSceneId,
      linkedLocationName: linkedLocationName ?? this.linkedLocationName,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<int>(projectId.value);
    }
    if (bibleId.present) {
      map['bible_id'] = Variable<int>(bibleId.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (caption.present) {
      map['caption'] = Variable<String>(caption.value);
    }
    if (filmReference.present) {
      map['film_reference'] = Variable<String>(filmReference.value);
    }
    if (linkedSceneId.present) {
      map['linked_scene_id'] = Variable<int>(linkedSceneId.value);
    }
    if (linkedLocationName.present) {
      map['linked_location_name'] = Variable<String>(linkedLocationName.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MoodboardImagesCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('bibleId: $bibleId, ')
          ..write('imagePath: $imagePath, ')
          ..write('source: $source, ')
          ..write('category: $category, ')
          ..write('caption: $caption, ')
          ..write('filmReference: $filmReference, ')
          ..write('linkedSceneId: $linkedSceneId, ')
          ..write('linkedLocationName: $linkedLocationName, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ProjectGroupsTable projectGroups = $ProjectGroupsTable(this);
  late final $ProjectsTable projects = $ProjectsTable(this);
  late final $LocationSitesTable locationSites = $LocationSitesTable(this);
  late final $LocationBasePlansTable locationBasePlans =
      $LocationBasePlansTable(this);
  late final $ScenesTable scenes = $ScenesTable(this);
  late final $ShotsTable shots = $ShotsTable(this);
  late final $ShotReferencesTable shotReferences = $ShotReferencesTable(this);
  late final $CameraPlanElementsTable cameraPlanElements =
      $CameraPlanElementsTable(this);
  late final $CameraPathPointsTable cameraPathPoints = $CameraPathPointsTable(
    this,
  );
  late final $LocationImagesTable locationImages = $LocationImagesTable(this);
  late final $SiteImagesTable siteImages = $SiteImagesTable(this);
  late final $CamerasTable cameras = $CamerasTable(this);
  late final $LensesTable lenses = $LensesTable(this);
  late final $LightsTable lights = $LightsTable(this);
  late final $ProjectEquipmentTable projectEquipment = $ProjectEquipmentTable(
    this,
  );
  late final $LookBiblesTable lookBibles = $LookBiblesTable(this);
  late final $ProjectAnnotatedPdfsTable projectAnnotatedPdfs =
      $ProjectAnnotatedPdfsTable(this);
  late final $VisualBiblesTable visualBibles = $VisualBiblesTable(this);
  late final $VisualBibleColorBlocksTable visualBibleColorBlocks =
      $VisualBibleColorBlocksTable(this);
  late final $VisualBibleLocationRefsTable visualBibleLocationRefs =
      $VisualBibleLocationRefsTable(this);
  late final $MoodboardImagesTable moodboardImages = $MoodboardImagesTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    projectGroups,
    projects,
    locationSites,
    locationBasePlans,
    scenes,
    shots,
    shotReferences,
    cameraPlanElements,
    cameraPathPoints,
    locationImages,
    siteImages,
    cameras,
    lenses,
    lights,
    projectEquipment,
    lookBibles,
    projectAnnotatedPdfs,
    visualBibles,
    visualBibleColorBlocks,
    visualBibleLocationRefs,
    moodboardImages,
  ];
}

typedef $$ProjectGroupsTableCreateCompanionBuilder =
    ProjectGroupsCompanion Function({
      Value<int> id,
      required String name,
      Value<int> sortOrder,
    });
typedef $$ProjectGroupsTableUpdateCompanionBuilder =
    ProjectGroupsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int> sortOrder,
    });

final class $$ProjectGroupsTableReferences
    extends BaseReferences<_$AppDatabase, $ProjectGroupsTable, ProjectGroup> {
  $$ProjectGroupsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$ProjectsTable, List<Project>> _projectsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.projects,
    aliasName: $_aliasNameGenerator(db.projectGroups.id, db.projects.groupId),
  );

  $$ProjectsTableProcessedTableManager get projectsRefs {
    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.groupId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_projectsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProjectGroupsTableFilterComposer
    extends Composer<_$AppDatabase, $ProjectGroupsTable> {
  $$ProjectGroupsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> projectsRefs(
    Expression<bool> Function($$ProjectsTableFilterComposer f) f,
  ) {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProjectGroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProjectGroupsTable> {
  $$ProjectGroupsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProjectGroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProjectGroupsTable> {
  $$ProjectGroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  Expression<T> projectsRefs<T extends Object>(
    Expression<T> Function($$ProjectsTableAnnotationComposer a) f,
  ) {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProjectGroupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProjectGroupsTable,
          ProjectGroup,
          $$ProjectGroupsTableFilterComposer,
          $$ProjectGroupsTableOrderingComposer,
          $$ProjectGroupsTableAnnotationComposer,
          $$ProjectGroupsTableCreateCompanionBuilder,
          $$ProjectGroupsTableUpdateCompanionBuilder,
          (ProjectGroup, $$ProjectGroupsTableReferences),
          ProjectGroup,
          PrefetchHooks Function({bool projectsRefs})
        > {
  $$ProjectGroupsTableTableManager(_$AppDatabase db, $ProjectGroupsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectGroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectGroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectGroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => ProjectGroupsCompanion(
                id: id,
                name: name,
                sortOrder: sortOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<int> sortOrder = const Value.absent(),
              }) => ProjectGroupsCompanion.insert(
                id: id,
                name: name,
                sortOrder: sortOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProjectGroupsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({projectsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (projectsRefs) db.projects],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (projectsRefs)
                    await $_getPrefetchedData<
                      ProjectGroup,
                      $ProjectGroupsTable,
                      Project
                    >(
                      currentTable: table,
                      referencedTable: $$ProjectGroupsTableReferences
                          ._projectsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ProjectGroupsTableReferences(
                            db,
                            table,
                            p0,
                          ).projectsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.groupId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ProjectGroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProjectGroupsTable,
      ProjectGroup,
      $$ProjectGroupsTableFilterComposer,
      $$ProjectGroupsTableOrderingComposer,
      $$ProjectGroupsTableAnnotationComposer,
      $$ProjectGroupsTableCreateCompanionBuilder,
      $$ProjectGroupsTableUpdateCompanionBuilder,
      (ProjectGroup, $$ProjectGroupsTableReferences),
      ProjectGroup,
      PrefetchHooks Function({bool projectsRefs})
    >;
typedef $$ProjectsTableCreateCompanionBuilder =
    ProjectsCompanion Function({
      Value<int> id,
      Value<int?> groupId,
      required String name,
      Value<String?> director,
      Value<String?> description,
      Value<String?> clientName,
      Value<String> status,
      Value<int> iconCode,
      Value<String?> coverImagePath,
      Value<String?> shootingStartDate,
      Value<String?> shootingEndDate,
      Value<String?> googleEmail,
      Value<String?> scriptFilePath,
      Value<String?> scriptFileName,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$ProjectsTableUpdateCompanionBuilder =
    ProjectsCompanion Function({
      Value<int> id,
      Value<int?> groupId,
      Value<String> name,
      Value<String?> director,
      Value<String?> description,
      Value<String?> clientName,
      Value<String> status,
      Value<int> iconCode,
      Value<String?> coverImagePath,
      Value<String?> shootingStartDate,
      Value<String?> shootingEndDate,
      Value<String?> googleEmail,
      Value<String?> scriptFilePath,
      Value<String?> scriptFileName,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$ProjectsTableReferences
    extends BaseReferences<_$AppDatabase, $ProjectsTable, Project> {
  $$ProjectsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectGroupsTable _groupIdTable(_$AppDatabase db) =>
      db.projectGroups.createAlias(
        $_aliasNameGenerator(db.projects.groupId, db.projectGroups.id),
      );

  $$ProjectGroupsTableProcessedTableManager? get groupId {
    final $_column = $_itemColumn<int>('group_id');
    if ($_column == null) return null;
    final manager = $$ProjectGroupsTableTableManager(
      $_db,
      $_db.projectGroups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_groupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$LocationSitesTable, List<LocationSite>>
  _locationSitesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.locationSites,
    aliasName: $_aliasNameGenerator(db.projects.id, db.locationSites.projectId),
  );

  $$LocationSitesTableProcessedTableManager get locationSitesRefs {
    final manager = $$LocationSitesTableTableManager(
      $_db,
      $_db.locationSites,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_locationSitesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LocationBasePlansTable, List<LocationBasePlan>>
  _locationBasePlansRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.locationBasePlans,
        aliasName: $_aliasNameGenerator(
          db.projects.id,
          db.locationBasePlans.projectId,
        ),
      );

  $$LocationBasePlansTableProcessedTableManager get locationBasePlansRefs {
    final manager = $$LocationBasePlansTableTableManager(
      $_db,
      $_db.locationBasePlans,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _locationBasePlansRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ScenesTable, List<Scene>> _scenesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.scenes,
    aliasName: $_aliasNameGenerator(db.projects.id, db.scenes.projectId),
  );

  $$ScenesTableProcessedTableManager get scenesRefs {
    final manager = $$ScenesTableTableManager(
      $_db,
      $_db.scenes,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_scenesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ShotsTable, List<Shot>> _shotsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.shots,
    aliasName: $_aliasNameGenerator(db.projects.id, db.shots.projectId),
  );

  $$ShotsTableProcessedTableManager get shotsRefs {
    final manager = $$ShotsTableTableManager(
      $_db,
      $_db.shots,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_shotsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ProjectEquipmentTable, List<ProjectEquipmentData>>
  _projectEquipmentRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.projectEquipment,
    aliasName: $_aliasNameGenerator(
      db.projects.id,
      db.projectEquipment.projectId,
    ),
  );

  $$ProjectEquipmentTableProcessedTableManager get projectEquipmentRefs {
    final manager = $$ProjectEquipmentTableTableManager(
      $_db,
      $_db.projectEquipment,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _projectEquipmentRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LookBiblesTable, List<LookBible>>
  _lookBiblesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.lookBibles,
    aliasName: $_aliasNameGenerator(db.projects.id, db.lookBibles.projectId),
  );

  $$LookBiblesTableProcessedTableManager get lookBiblesRefs {
    final manager = $$LookBiblesTableTableManager(
      $_db,
      $_db.lookBibles,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_lookBiblesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $ProjectAnnotatedPdfsTable,
    List<ProjectAnnotatedPdf>
  >
  _projectAnnotatedPdfsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.projectAnnotatedPdfs,
        aliasName: $_aliasNameGenerator(
          db.projects.id,
          db.projectAnnotatedPdfs.projectId,
        ),
      );

  $$ProjectAnnotatedPdfsTableProcessedTableManager
  get projectAnnotatedPdfsRefs {
    final manager = $$ProjectAnnotatedPdfsTableTableManager(
      $_db,
      $_db.projectAnnotatedPdfs,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _projectAnnotatedPdfsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$VisualBiblesTable, List<VisualBible>>
  _visualBiblesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.visualBibles,
    aliasName: $_aliasNameGenerator(db.projects.id, db.visualBibles.projectId),
  );

  $$VisualBiblesTableProcessedTableManager get visualBiblesRefs {
    final manager = $$VisualBiblesTableTableManager(
      $_db,
      $_db.visualBibles,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_visualBiblesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MoodboardImagesTable, List<MoodboardImage>>
  _moodboardImagesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.moodboardImages,
    aliasName: $_aliasNameGenerator(
      db.projects.id,
      db.moodboardImages.projectId,
    ),
  );

  $$MoodboardImagesTableProcessedTableManager get moodboardImagesRefs {
    final manager = $$MoodboardImagesTableTableManager(
      $_db,
      $_db.moodboardImages,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _moodboardImagesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProjectsTableFilterComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get director => $composableBuilder(
    column: $table.director,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientName => $composableBuilder(
    column: $table.clientName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get iconCode => $composableBuilder(
    column: $table.iconCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverImagePath => $composableBuilder(
    column: $table.coverImagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shootingStartDate => $composableBuilder(
    column: $table.shootingStartDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shootingEndDate => $composableBuilder(
    column: $table.shootingEndDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get googleEmail => $composableBuilder(
    column: $table.googleEmail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scriptFilePath => $composableBuilder(
    column: $table.scriptFilePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scriptFileName => $composableBuilder(
    column: $table.scriptFileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectGroupsTableFilterComposer get groupId {
    final $$ProjectGroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.projectGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectGroupsTableFilterComposer(
            $db: $db,
            $table: $db.projectGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> locationSitesRefs(
    Expression<bool> Function($$LocationSitesTableFilterComposer f) f,
  ) {
    final $$LocationSitesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.locationSites,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocationSitesTableFilterComposer(
            $db: $db,
            $table: $db.locationSites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> locationBasePlansRefs(
    Expression<bool> Function($$LocationBasePlansTableFilterComposer f) f,
  ) {
    final $$LocationBasePlansTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.locationBasePlans,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocationBasePlansTableFilterComposer(
            $db: $db,
            $table: $db.locationBasePlans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> scenesRefs(
    Expression<bool> Function($$ScenesTableFilterComposer f) f,
  ) {
    final $$ScenesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.scenes,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScenesTableFilterComposer(
            $db: $db,
            $table: $db.scenes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> shotsRefs(
    Expression<bool> Function($$ShotsTableFilterComposer f) f,
  ) {
    final $$ShotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shots,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShotsTableFilterComposer(
            $db: $db,
            $table: $db.shots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> projectEquipmentRefs(
    Expression<bool> Function($$ProjectEquipmentTableFilterComposer f) f,
  ) {
    final $$ProjectEquipmentTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.projectEquipment,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectEquipmentTableFilterComposer(
            $db: $db,
            $table: $db.projectEquipment,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> lookBiblesRefs(
    Expression<bool> Function($$LookBiblesTableFilterComposer f) f,
  ) {
    final $$LookBiblesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.lookBibles,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LookBiblesTableFilterComposer(
            $db: $db,
            $table: $db.lookBibles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> projectAnnotatedPdfsRefs(
    Expression<bool> Function($$ProjectAnnotatedPdfsTableFilterComposer f) f,
  ) {
    final $$ProjectAnnotatedPdfsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.projectAnnotatedPdfs,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectAnnotatedPdfsTableFilterComposer(
            $db: $db,
            $table: $db.projectAnnotatedPdfs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> visualBiblesRefs(
    Expression<bool> Function($$VisualBiblesTableFilterComposer f) f,
  ) {
    final $$VisualBiblesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.visualBibles,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VisualBiblesTableFilterComposer(
            $db: $db,
            $table: $db.visualBibles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> moodboardImagesRefs(
    Expression<bool> Function($$MoodboardImagesTableFilterComposer f) f,
  ) {
    final $$MoodboardImagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.moodboardImages,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MoodboardImagesTableFilterComposer(
            $db: $db,
            $table: $db.moodboardImages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProjectsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get director => $composableBuilder(
    column: $table.director,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientName => $composableBuilder(
    column: $table.clientName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get iconCode => $composableBuilder(
    column: $table.iconCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverImagePath => $composableBuilder(
    column: $table.coverImagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shootingStartDate => $composableBuilder(
    column: $table.shootingStartDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shootingEndDate => $composableBuilder(
    column: $table.shootingEndDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get googleEmail => $composableBuilder(
    column: $table.googleEmail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scriptFilePath => $composableBuilder(
    column: $table.scriptFilePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scriptFileName => $composableBuilder(
    column: $table.scriptFileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectGroupsTableOrderingComposer get groupId {
    final $$ProjectGroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.projectGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectGroupsTableOrderingComposer(
            $db: $db,
            $table: $db.projectGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProjectsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get director =>
      $composableBuilder(column: $table.director, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get clientName => $composableBuilder(
    column: $table.clientName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get iconCode =>
      $composableBuilder(column: $table.iconCode, builder: (column) => column);

  GeneratedColumn<String> get coverImagePath => $composableBuilder(
    column: $table.coverImagePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get shootingStartDate => $composableBuilder(
    column: $table.shootingStartDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get shootingEndDate => $composableBuilder(
    column: $table.shootingEndDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get googleEmail => $composableBuilder(
    column: $table.googleEmail,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scriptFilePath => $composableBuilder(
    column: $table.scriptFilePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scriptFileName => $composableBuilder(
    column: $table.scriptFileName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ProjectGroupsTableAnnotationComposer get groupId {
    final $$ProjectGroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.projectGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectGroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.projectGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> locationSitesRefs<T extends Object>(
    Expression<T> Function($$LocationSitesTableAnnotationComposer a) f,
  ) {
    final $$LocationSitesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.locationSites,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocationSitesTableAnnotationComposer(
            $db: $db,
            $table: $db.locationSites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> locationBasePlansRefs<T extends Object>(
    Expression<T> Function($$LocationBasePlansTableAnnotationComposer a) f,
  ) {
    final $$LocationBasePlansTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.locationBasePlans,
          getReferencedColumn: (t) => t.projectId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LocationBasePlansTableAnnotationComposer(
                $db: $db,
                $table: $db.locationBasePlans,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> scenesRefs<T extends Object>(
    Expression<T> Function($$ScenesTableAnnotationComposer a) f,
  ) {
    final $$ScenesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.scenes,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScenesTableAnnotationComposer(
            $db: $db,
            $table: $db.scenes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> shotsRefs<T extends Object>(
    Expression<T> Function($$ShotsTableAnnotationComposer a) f,
  ) {
    final $$ShotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shots,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShotsTableAnnotationComposer(
            $db: $db,
            $table: $db.shots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> projectEquipmentRefs<T extends Object>(
    Expression<T> Function($$ProjectEquipmentTableAnnotationComposer a) f,
  ) {
    final $$ProjectEquipmentTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.projectEquipment,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectEquipmentTableAnnotationComposer(
            $db: $db,
            $table: $db.projectEquipment,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> lookBiblesRefs<T extends Object>(
    Expression<T> Function($$LookBiblesTableAnnotationComposer a) f,
  ) {
    final $$LookBiblesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.lookBibles,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LookBiblesTableAnnotationComposer(
            $db: $db,
            $table: $db.lookBibles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> projectAnnotatedPdfsRefs<T extends Object>(
    Expression<T> Function($$ProjectAnnotatedPdfsTableAnnotationComposer a) f,
  ) {
    final $$ProjectAnnotatedPdfsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.projectAnnotatedPdfs,
          getReferencedColumn: (t) => t.projectId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ProjectAnnotatedPdfsTableAnnotationComposer(
                $db: $db,
                $table: $db.projectAnnotatedPdfs,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> visualBiblesRefs<T extends Object>(
    Expression<T> Function($$VisualBiblesTableAnnotationComposer a) f,
  ) {
    final $$VisualBiblesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.visualBibles,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VisualBiblesTableAnnotationComposer(
            $db: $db,
            $table: $db.visualBibles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> moodboardImagesRefs<T extends Object>(
    Expression<T> Function($$MoodboardImagesTableAnnotationComposer a) f,
  ) {
    final $$MoodboardImagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.moodboardImages,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MoodboardImagesTableAnnotationComposer(
            $db: $db,
            $table: $db.moodboardImages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProjectsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProjectsTable,
          Project,
          $$ProjectsTableFilterComposer,
          $$ProjectsTableOrderingComposer,
          $$ProjectsTableAnnotationComposer,
          $$ProjectsTableCreateCompanionBuilder,
          $$ProjectsTableUpdateCompanionBuilder,
          (Project, $$ProjectsTableReferences),
          Project,
          PrefetchHooks Function({
            bool groupId,
            bool locationSitesRefs,
            bool locationBasePlansRefs,
            bool scenesRefs,
            bool shotsRefs,
            bool projectEquipmentRefs,
            bool lookBiblesRefs,
            bool projectAnnotatedPdfsRefs,
            bool visualBiblesRefs,
            bool moodboardImagesRefs,
          })
        > {
  $$ProjectsTableTableManager(_$AppDatabase db, $ProjectsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> groupId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> director = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> clientName = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> iconCode = const Value.absent(),
                Value<String?> coverImagePath = const Value.absent(),
                Value<String?> shootingStartDate = const Value.absent(),
                Value<String?> shootingEndDate = const Value.absent(),
                Value<String?> googleEmail = const Value.absent(),
                Value<String?> scriptFilePath = const Value.absent(),
                Value<String?> scriptFileName = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ProjectsCompanion(
                id: id,
                groupId: groupId,
                name: name,
                director: director,
                description: description,
                clientName: clientName,
                status: status,
                iconCode: iconCode,
                coverImagePath: coverImagePath,
                shootingStartDate: shootingStartDate,
                shootingEndDate: shootingEndDate,
                googleEmail: googleEmail,
                scriptFilePath: scriptFilePath,
                scriptFileName: scriptFileName,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> groupId = const Value.absent(),
                required String name,
                Value<String?> director = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> clientName = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> iconCode = const Value.absent(),
                Value<String?> coverImagePath = const Value.absent(),
                Value<String?> shootingStartDate = const Value.absent(),
                Value<String?> shootingEndDate = const Value.absent(),
                Value<String?> googleEmail = const Value.absent(),
                Value<String?> scriptFilePath = const Value.absent(),
                Value<String?> scriptFileName = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ProjectsCompanion.insert(
                id: id,
                groupId: groupId,
                name: name,
                director: director,
                description: description,
                clientName: clientName,
                status: status,
                iconCode: iconCode,
                coverImagePath: coverImagePath,
                shootingStartDate: shootingStartDate,
                shootingEndDate: shootingEndDate,
                googleEmail: googleEmail,
                scriptFilePath: scriptFilePath,
                scriptFileName: scriptFileName,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProjectsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                groupId = false,
                locationSitesRefs = false,
                locationBasePlansRefs = false,
                scenesRefs = false,
                shotsRefs = false,
                projectEquipmentRefs = false,
                lookBiblesRefs = false,
                projectAnnotatedPdfsRefs = false,
                visualBiblesRefs = false,
                moodboardImagesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (locationSitesRefs) db.locationSites,
                    if (locationBasePlansRefs) db.locationBasePlans,
                    if (scenesRefs) db.scenes,
                    if (shotsRefs) db.shots,
                    if (projectEquipmentRefs) db.projectEquipment,
                    if (lookBiblesRefs) db.lookBibles,
                    if (projectAnnotatedPdfsRefs) db.projectAnnotatedPdfs,
                    if (visualBiblesRefs) db.visualBibles,
                    if (moodboardImagesRefs) db.moodboardImages,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (groupId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.groupId,
                                    referencedTable: $$ProjectsTableReferences
                                        ._groupIdTable(db),
                                    referencedColumn: $$ProjectsTableReferences
                                        ._groupIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (locationSitesRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          LocationSite
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._locationSitesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).locationSitesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (locationBasePlansRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          LocationBasePlan
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._locationBasePlansRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).locationBasePlansRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (scenesRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          Scene
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._scenesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).scenesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (shotsRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          Shot
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._shotsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).shotsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (projectEquipmentRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          ProjectEquipmentData
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._projectEquipmentRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).projectEquipmentRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (lookBiblesRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          LookBible
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._lookBiblesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).lookBiblesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (projectAnnotatedPdfsRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          ProjectAnnotatedPdf
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._projectAnnotatedPdfsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).projectAnnotatedPdfsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (visualBiblesRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          VisualBible
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._visualBiblesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).visualBiblesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (moodboardImagesRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          MoodboardImage
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._moodboardImagesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).moodboardImagesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ProjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProjectsTable,
      Project,
      $$ProjectsTableFilterComposer,
      $$ProjectsTableOrderingComposer,
      $$ProjectsTableAnnotationComposer,
      $$ProjectsTableCreateCompanionBuilder,
      $$ProjectsTableUpdateCompanionBuilder,
      (Project, $$ProjectsTableReferences),
      Project,
      PrefetchHooks Function({
        bool groupId,
        bool locationSitesRefs,
        bool locationBasePlansRefs,
        bool scenesRefs,
        bool shotsRefs,
        bool projectEquipmentRefs,
        bool lookBiblesRefs,
        bool projectAnnotatedPdfsRefs,
        bool visualBiblesRefs,
        bool moodboardImagesRefs,
      })
    >;
typedef $$LocationSitesTableCreateCompanionBuilder =
    LocationSitesCompanion Function({
      Value<int> id,
      required int projectId,
      required String name,
      Value<String?> description,
      Value<String?> notes,
      Value<String?> floorPlanJson,
      Value<String?> scanPath,
      Value<String?> scanSource,
      Value<String?> scanMetadataJson,
      Value<int> sortOrder,
    });
typedef $$LocationSitesTableUpdateCompanionBuilder =
    LocationSitesCompanion Function({
      Value<int> id,
      Value<int> projectId,
      Value<String> name,
      Value<String?> description,
      Value<String?> notes,
      Value<String?> floorPlanJson,
      Value<String?> scanPath,
      Value<String?> scanSource,
      Value<String?> scanMetadataJson,
      Value<int> sortOrder,
    });

final class $$LocationSitesTableReferences
    extends BaseReferences<_$AppDatabase, $LocationSitesTable, LocationSite> {
  $$LocationSitesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias(
        $_aliasNameGenerator(db.locationSites.projectId, db.projects.id),
      );

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<int>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$LocationBasePlansTable, List<LocationBasePlan>>
  _locationBasePlansRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.locationBasePlans,
        aliasName: $_aliasNameGenerator(
          db.locationSites.id,
          db.locationBasePlans.siteId,
        ),
      );

  $$LocationBasePlansTableProcessedTableManager get locationBasePlansRefs {
    final manager = $$LocationBasePlansTableTableManager(
      $_db,
      $_db.locationBasePlans,
    ).filter((f) => f.siteId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _locationBasePlansRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ScenesTable, List<Scene>> _scenesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.scenes,
    aliasName: $_aliasNameGenerator(
      db.locationSites.id,
      db.scenes.locationSiteId,
    ),
  );

  $$ScenesTableProcessedTableManager get scenesRefs {
    final manager = $$ScenesTableTableManager(
      $_db,
      $_db.scenes,
    ).filter((f) => f.locationSiteId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_scenesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SiteImagesTable, List<SiteImage>>
  _siteImagesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.siteImages,
    aliasName: $_aliasNameGenerator(db.locationSites.id, db.siteImages.siteId),
  );

  $$SiteImagesTableProcessedTableManager get siteImagesRefs {
    final manager = $$SiteImagesTableTableManager(
      $_db,
      $_db.siteImages,
    ).filter((f) => f.siteId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_siteImagesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LocationSitesTableFilterComposer
    extends Composer<_$AppDatabase, $LocationSitesTable> {
  $$LocationSitesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get floorPlanJson => $composableBuilder(
    column: $table.floorPlanJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scanPath => $composableBuilder(
    column: $table.scanPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scanSource => $composableBuilder(
    column: $table.scanSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scanMetadataJson => $composableBuilder(
    column: $table.scanMetadataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> locationBasePlansRefs(
    Expression<bool> Function($$LocationBasePlansTableFilterComposer f) f,
  ) {
    final $$LocationBasePlansTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.locationBasePlans,
      getReferencedColumn: (t) => t.siteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocationBasePlansTableFilterComposer(
            $db: $db,
            $table: $db.locationBasePlans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> scenesRefs(
    Expression<bool> Function($$ScenesTableFilterComposer f) f,
  ) {
    final $$ScenesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.scenes,
      getReferencedColumn: (t) => t.locationSiteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScenesTableFilterComposer(
            $db: $db,
            $table: $db.scenes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> siteImagesRefs(
    Expression<bool> Function($$SiteImagesTableFilterComposer f) f,
  ) {
    final $$SiteImagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.siteImages,
      getReferencedColumn: (t) => t.siteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SiteImagesTableFilterComposer(
            $db: $db,
            $table: $db.siteImages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LocationSitesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocationSitesTable> {
  $$LocationSitesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get floorPlanJson => $composableBuilder(
    column: $table.floorPlanJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scanPath => $composableBuilder(
    column: $table.scanPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scanSource => $composableBuilder(
    column: $table.scanSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scanMetadataJson => $composableBuilder(
    column: $table.scanMetadataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocationSitesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocationSitesTable> {
  $$LocationSitesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get floorPlanJson => $composableBuilder(
    column: $table.floorPlanJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scanPath =>
      $composableBuilder(column: $table.scanPath, builder: (column) => column);

  GeneratedColumn<String> get scanSource => $composableBuilder(
    column: $table.scanSource,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scanMetadataJson => $composableBuilder(
    column: $table.scanMetadataJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> locationBasePlansRefs<T extends Object>(
    Expression<T> Function($$LocationBasePlansTableAnnotationComposer a) f,
  ) {
    final $$LocationBasePlansTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.locationBasePlans,
          getReferencedColumn: (t) => t.siteId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LocationBasePlansTableAnnotationComposer(
                $db: $db,
                $table: $db.locationBasePlans,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> scenesRefs<T extends Object>(
    Expression<T> Function($$ScenesTableAnnotationComposer a) f,
  ) {
    final $$ScenesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.scenes,
      getReferencedColumn: (t) => t.locationSiteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScenesTableAnnotationComposer(
            $db: $db,
            $table: $db.scenes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> siteImagesRefs<T extends Object>(
    Expression<T> Function($$SiteImagesTableAnnotationComposer a) f,
  ) {
    final $$SiteImagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.siteImages,
      getReferencedColumn: (t) => t.siteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SiteImagesTableAnnotationComposer(
            $db: $db,
            $table: $db.siteImages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LocationSitesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocationSitesTable,
          LocationSite,
          $$LocationSitesTableFilterComposer,
          $$LocationSitesTableOrderingComposer,
          $$LocationSitesTableAnnotationComposer,
          $$LocationSitesTableCreateCompanionBuilder,
          $$LocationSitesTableUpdateCompanionBuilder,
          (LocationSite, $$LocationSitesTableReferences),
          LocationSite,
          PrefetchHooks Function({
            bool projectId,
            bool locationBasePlansRefs,
            bool scenesRefs,
            bool siteImagesRefs,
          })
        > {
  $$LocationSitesTableTableManager(_$AppDatabase db, $LocationSitesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocationSitesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocationSitesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocationSitesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> projectId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> floorPlanJson = const Value.absent(),
                Value<String?> scanPath = const Value.absent(),
                Value<String?> scanSource = const Value.absent(),
                Value<String?> scanMetadataJson = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => LocationSitesCompanion(
                id: id,
                projectId: projectId,
                name: name,
                description: description,
                notes: notes,
                floorPlanJson: floorPlanJson,
                scanPath: scanPath,
                scanSource: scanSource,
                scanMetadataJson: scanMetadataJson,
                sortOrder: sortOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int projectId,
                required String name,
                Value<String?> description = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> floorPlanJson = const Value.absent(),
                Value<String?> scanPath = const Value.absent(),
                Value<String?> scanSource = const Value.absent(),
                Value<String?> scanMetadataJson = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => LocationSitesCompanion.insert(
                id: id,
                projectId: projectId,
                name: name,
                description: description,
                notes: notes,
                floorPlanJson: floorPlanJson,
                scanPath: scanPath,
                scanSource: scanSource,
                scanMetadataJson: scanMetadataJson,
                sortOrder: sortOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LocationSitesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                projectId = false,
                locationBasePlansRefs = false,
                scenesRefs = false,
                siteImagesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (locationBasePlansRefs) db.locationBasePlans,
                    if (scenesRefs) db.scenes,
                    if (siteImagesRefs) db.siteImages,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (projectId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.projectId,
                                    referencedTable:
                                        $$LocationSitesTableReferences
                                            ._projectIdTable(db),
                                    referencedColumn:
                                        $$LocationSitesTableReferences
                                            ._projectIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (locationBasePlansRefs)
                        await $_getPrefetchedData<
                          LocationSite,
                          $LocationSitesTable,
                          LocationBasePlan
                        >(
                          currentTable: table,
                          referencedTable: $$LocationSitesTableReferences
                              ._locationBasePlansRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LocationSitesTableReferences(
                                db,
                                table,
                                p0,
                              ).locationBasePlansRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.siteId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (scenesRefs)
                        await $_getPrefetchedData<
                          LocationSite,
                          $LocationSitesTable,
                          Scene
                        >(
                          currentTable: table,
                          referencedTable: $$LocationSitesTableReferences
                              ._scenesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LocationSitesTableReferences(
                                db,
                                table,
                                p0,
                              ).scenesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.locationSiteId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (siteImagesRefs)
                        await $_getPrefetchedData<
                          LocationSite,
                          $LocationSitesTable,
                          SiteImage
                        >(
                          currentTable: table,
                          referencedTable: $$LocationSitesTableReferences
                              ._siteImagesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LocationSitesTableReferences(
                                db,
                                table,
                                p0,
                              ).siteImagesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.siteId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$LocationSitesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocationSitesTable,
      LocationSite,
      $$LocationSitesTableFilterComposer,
      $$LocationSitesTableOrderingComposer,
      $$LocationSitesTableAnnotationComposer,
      $$LocationSitesTableCreateCompanionBuilder,
      $$LocationSitesTableUpdateCompanionBuilder,
      (LocationSite, $$LocationSitesTableReferences),
      LocationSite,
      PrefetchHooks Function({
        bool projectId,
        bool locationBasePlansRefs,
        bool scenesRefs,
        bool siteImagesRefs,
      })
    >;
typedef $$LocationBasePlansTableCreateCompanionBuilder =
    LocationBasePlansCompanion Function({
      Value<int> id,
      required int projectId,
      Value<int?> siteId,
      required String locationName,
      Value<String?> description,
      Value<String?> imagePath,
      Value<String> color,
      Value<String?> notes,
      Value<String?> model3dPath,
      Value<String?> floorPlanJson,
      Value<String?> scanPath,
      Value<String?> scanSource,
      Value<String?> scanMetadataJson,
      Value<int> sortOrder,
    });
typedef $$LocationBasePlansTableUpdateCompanionBuilder =
    LocationBasePlansCompanion Function({
      Value<int> id,
      Value<int> projectId,
      Value<int?> siteId,
      Value<String> locationName,
      Value<String?> description,
      Value<String?> imagePath,
      Value<String> color,
      Value<String?> notes,
      Value<String?> model3dPath,
      Value<String?> floorPlanJson,
      Value<String?> scanPath,
      Value<String?> scanSource,
      Value<String?> scanMetadataJson,
      Value<int> sortOrder,
    });

final class $$LocationBasePlansTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $LocationBasePlansTable,
          LocationBasePlan
        > {
  $$LocationBasePlansTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias(
        $_aliasNameGenerator(db.locationBasePlans.projectId, db.projects.id),
      );

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<int>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $LocationSitesTable _siteIdTable(_$AppDatabase db) =>
      db.locationSites.createAlias(
        $_aliasNameGenerator(db.locationBasePlans.siteId, db.locationSites.id),
      );

  $$LocationSitesTableProcessedTableManager? get siteId {
    final $_column = $_itemColumn<int>('site_id');
    if ($_column == null) return null;
    final manager = $$LocationSitesTableTableManager(
      $_db,
      $_db.locationSites,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_siteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ScenesTable, List<Scene>> _scenesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.scenes,
    aliasName: $_aliasNameGenerator(
      db.locationBasePlans.id,
      db.scenes.locationId,
    ),
  );

  $$ScenesTableProcessedTableManager get scenesRefs {
    final manager = $$ScenesTableTableManager(
      $_db,
      $_db.scenes,
    ).filter((f) => f.locationId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_scenesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LocationImagesTable, List<LocationImage>>
  _locationImagesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.locationImages,
    aliasName: $_aliasNameGenerator(
      db.locationBasePlans.id,
      db.locationImages.locationId,
    ),
  );

  $$LocationImagesTableProcessedTableManager get locationImagesRefs {
    final manager = $$LocationImagesTableTableManager(
      $_db,
      $_db.locationImages,
    ).filter((f) => f.locationId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_locationImagesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LocationBasePlansTableFilterComposer
    extends Composer<_$AppDatabase, $LocationBasePlansTable> {
  $$LocationBasePlansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locationName => $composableBuilder(
    column: $table.locationName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model3dPath => $composableBuilder(
    column: $table.model3dPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get floorPlanJson => $composableBuilder(
    column: $table.floorPlanJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scanPath => $composableBuilder(
    column: $table.scanPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scanSource => $composableBuilder(
    column: $table.scanSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scanMetadataJson => $composableBuilder(
    column: $table.scanMetadataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LocationSitesTableFilterComposer get siteId {
    final $$LocationSitesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.siteId,
      referencedTable: $db.locationSites,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocationSitesTableFilterComposer(
            $db: $db,
            $table: $db.locationSites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> scenesRefs(
    Expression<bool> Function($$ScenesTableFilterComposer f) f,
  ) {
    final $$ScenesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.scenes,
      getReferencedColumn: (t) => t.locationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScenesTableFilterComposer(
            $db: $db,
            $table: $db.scenes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> locationImagesRefs(
    Expression<bool> Function($$LocationImagesTableFilterComposer f) f,
  ) {
    final $$LocationImagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.locationImages,
      getReferencedColumn: (t) => t.locationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocationImagesTableFilterComposer(
            $db: $db,
            $table: $db.locationImages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LocationBasePlansTableOrderingComposer
    extends Composer<_$AppDatabase, $LocationBasePlansTable> {
  $$LocationBasePlansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locationName => $composableBuilder(
    column: $table.locationName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model3dPath => $composableBuilder(
    column: $table.model3dPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get floorPlanJson => $composableBuilder(
    column: $table.floorPlanJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scanPath => $composableBuilder(
    column: $table.scanPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scanSource => $composableBuilder(
    column: $table.scanSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scanMetadataJson => $composableBuilder(
    column: $table.scanMetadataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LocationSitesTableOrderingComposer get siteId {
    final $$LocationSitesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.siteId,
      referencedTable: $db.locationSites,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocationSitesTableOrderingComposer(
            $db: $db,
            $table: $db.locationSites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocationBasePlansTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocationBasePlansTable> {
  $$LocationBasePlansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get locationName => $composableBuilder(
    column: $table.locationName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get model3dPath => $composableBuilder(
    column: $table.model3dPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get floorPlanJson => $composableBuilder(
    column: $table.floorPlanJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scanPath =>
      $composableBuilder(column: $table.scanPath, builder: (column) => column);

  GeneratedColumn<String> get scanSource => $composableBuilder(
    column: $table.scanSource,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scanMetadataJson => $composableBuilder(
    column: $table.scanMetadataJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LocationSitesTableAnnotationComposer get siteId {
    final $$LocationSitesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.siteId,
      referencedTable: $db.locationSites,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocationSitesTableAnnotationComposer(
            $db: $db,
            $table: $db.locationSites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> scenesRefs<T extends Object>(
    Expression<T> Function($$ScenesTableAnnotationComposer a) f,
  ) {
    final $$ScenesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.scenes,
      getReferencedColumn: (t) => t.locationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScenesTableAnnotationComposer(
            $db: $db,
            $table: $db.scenes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> locationImagesRefs<T extends Object>(
    Expression<T> Function($$LocationImagesTableAnnotationComposer a) f,
  ) {
    final $$LocationImagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.locationImages,
      getReferencedColumn: (t) => t.locationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocationImagesTableAnnotationComposer(
            $db: $db,
            $table: $db.locationImages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LocationBasePlansTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocationBasePlansTable,
          LocationBasePlan,
          $$LocationBasePlansTableFilterComposer,
          $$LocationBasePlansTableOrderingComposer,
          $$LocationBasePlansTableAnnotationComposer,
          $$LocationBasePlansTableCreateCompanionBuilder,
          $$LocationBasePlansTableUpdateCompanionBuilder,
          (LocationBasePlan, $$LocationBasePlansTableReferences),
          LocationBasePlan,
          PrefetchHooks Function({
            bool projectId,
            bool siteId,
            bool scenesRefs,
            bool locationImagesRefs,
          })
        > {
  $$LocationBasePlansTableTableManager(
    _$AppDatabase db,
    $LocationBasePlansTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocationBasePlansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocationBasePlansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocationBasePlansTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> projectId = const Value.absent(),
                Value<int?> siteId = const Value.absent(),
                Value<String> locationName = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> imagePath = const Value.absent(),
                Value<String> color = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> model3dPath = const Value.absent(),
                Value<String?> floorPlanJson = const Value.absent(),
                Value<String?> scanPath = const Value.absent(),
                Value<String?> scanSource = const Value.absent(),
                Value<String?> scanMetadataJson = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => LocationBasePlansCompanion(
                id: id,
                projectId: projectId,
                siteId: siteId,
                locationName: locationName,
                description: description,
                imagePath: imagePath,
                color: color,
                notes: notes,
                model3dPath: model3dPath,
                floorPlanJson: floorPlanJson,
                scanPath: scanPath,
                scanSource: scanSource,
                scanMetadataJson: scanMetadataJson,
                sortOrder: sortOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int projectId,
                Value<int?> siteId = const Value.absent(),
                required String locationName,
                Value<String?> description = const Value.absent(),
                Value<String?> imagePath = const Value.absent(),
                Value<String> color = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> model3dPath = const Value.absent(),
                Value<String?> floorPlanJson = const Value.absent(),
                Value<String?> scanPath = const Value.absent(),
                Value<String?> scanSource = const Value.absent(),
                Value<String?> scanMetadataJson = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => LocationBasePlansCompanion.insert(
                id: id,
                projectId: projectId,
                siteId: siteId,
                locationName: locationName,
                description: description,
                imagePath: imagePath,
                color: color,
                notes: notes,
                model3dPath: model3dPath,
                floorPlanJson: floorPlanJson,
                scanPath: scanPath,
                scanSource: scanSource,
                scanMetadataJson: scanMetadataJson,
                sortOrder: sortOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LocationBasePlansTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                projectId = false,
                siteId = false,
                scenesRefs = false,
                locationImagesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (scenesRefs) db.scenes,
                    if (locationImagesRefs) db.locationImages,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (projectId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.projectId,
                                    referencedTable:
                                        $$LocationBasePlansTableReferences
                                            ._projectIdTable(db),
                                    referencedColumn:
                                        $$LocationBasePlansTableReferences
                                            ._projectIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (siteId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.siteId,
                                    referencedTable:
                                        $$LocationBasePlansTableReferences
                                            ._siteIdTable(db),
                                    referencedColumn:
                                        $$LocationBasePlansTableReferences
                                            ._siteIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (scenesRefs)
                        await $_getPrefetchedData<
                          LocationBasePlan,
                          $LocationBasePlansTable,
                          Scene
                        >(
                          currentTable: table,
                          referencedTable: $$LocationBasePlansTableReferences
                              ._scenesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LocationBasePlansTableReferences(
                                db,
                                table,
                                p0,
                              ).scenesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.locationId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (locationImagesRefs)
                        await $_getPrefetchedData<
                          LocationBasePlan,
                          $LocationBasePlansTable,
                          LocationImage
                        >(
                          currentTable: table,
                          referencedTable: $$LocationBasePlansTableReferences
                              ._locationImagesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LocationBasePlansTableReferences(
                                db,
                                table,
                                p0,
                              ).locationImagesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.locationId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$LocationBasePlansTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocationBasePlansTable,
      LocationBasePlan,
      $$LocationBasePlansTableFilterComposer,
      $$LocationBasePlansTableOrderingComposer,
      $$LocationBasePlansTableAnnotationComposer,
      $$LocationBasePlansTableCreateCompanionBuilder,
      $$LocationBasePlansTableUpdateCompanionBuilder,
      (LocationBasePlan, $$LocationBasePlansTableReferences),
      LocationBasePlan,
      PrefetchHooks Function({
        bool projectId,
        bool siteId,
        bool scenesRefs,
        bool locationImagesRefs,
      })
    >;
typedef $$ScenesTableCreateCompanionBuilder =
    ScenesCompanion Function({
      Value<int> id,
      required int projectId,
      required int number,
      required String name,
      required String locationCanonical,
      required String locationPureName,
      Value<int?> locationSiteId,
      Value<int?> locationId,
      Value<String> intExt,
      Value<String> dayNight,
      Value<String?> locationColor,
      Value<String?> description,
      Value<String?> actionText,
      Value<int?> sourceStartIndex,
      Value<int> durationMinutes,
      Value<bool> autoNumbering,
      Value<int> sortOrder,
    });
typedef $$ScenesTableUpdateCompanionBuilder =
    ScenesCompanion Function({
      Value<int> id,
      Value<int> projectId,
      Value<int> number,
      Value<String> name,
      Value<String> locationCanonical,
      Value<String> locationPureName,
      Value<int?> locationSiteId,
      Value<int?> locationId,
      Value<String> intExt,
      Value<String> dayNight,
      Value<String?> locationColor,
      Value<String?> description,
      Value<String?> actionText,
      Value<int?> sourceStartIndex,
      Value<int> durationMinutes,
      Value<bool> autoNumbering,
      Value<int> sortOrder,
    });

final class $$ScenesTableReferences
    extends BaseReferences<_$AppDatabase, $ScenesTable, Scene> {
  $$ScenesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$AppDatabase db) => db.projects
      .createAlias($_aliasNameGenerator(db.scenes.projectId, db.projects.id));

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<int>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $LocationSitesTable _locationSiteIdTable(_$AppDatabase db) =>
      db.locationSites.createAlias(
        $_aliasNameGenerator(db.scenes.locationSiteId, db.locationSites.id),
      );

  $$LocationSitesTableProcessedTableManager? get locationSiteId {
    final $_column = $_itemColumn<int>('location_site_id');
    if ($_column == null) return null;
    final manager = $$LocationSitesTableTableManager(
      $_db,
      $_db.locationSites,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_locationSiteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $LocationBasePlansTable _locationIdTable(_$AppDatabase db) =>
      db.locationBasePlans.createAlias(
        $_aliasNameGenerator(db.scenes.locationId, db.locationBasePlans.id),
      );

  $$LocationBasePlansTableProcessedTableManager? get locationId {
    final $_column = $_itemColumn<int>('location_id');
    if ($_column == null) return null;
    final manager = $$LocationBasePlansTableTableManager(
      $_db,
      $_db.locationBasePlans,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_locationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ShotsTable, List<Shot>> _shotsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.shots,
    aliasName: $_aliasNameGenerator(db.scenes.id, db.shots.sceneId),
  );

  $$ShotsTableProcessedTableManager get shotsRefs {
    final manager = $$ShotsTableTableManager(
      $_db,
      $_db.shots,
    ).filter((f) => f.sceneId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_shotsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ScenesTableFilterComposer
    extends Composer<_$AppDatabase, $ScenesTable> {
  $$ScenesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locationCanonical => $composableBuilder(
    column: $table.locationCanonical,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locationPureName => $composableBuilder(
    column: $table.locationPureName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get intExt => $composableBuilder(
    column: $table.intExt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dayNight => $composableBuilder(
    column: $table.dayNight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locationColor => $composableBuilder(
    column: $table.locationColor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actionText => $composableBuilder(
    column: $table.actionText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sourceStartIndex => $composableBuilder(
    column: $table.sourceStartIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get autoNumbering => $composableBuilder(
    column: $table.autoNumbering,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LocationSitesTableFilterComposer get locationSiteId {
    final $$LocationSitesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.locationSiteId,
      referencedTable: $db.locationSites,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocationSitesTableFilterComposer(
            $db: $db,
            $table: $db.locationSites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LocationBasePlansTableFilterComposer get locationId {
    final $$LocationBasePlansTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.locationId,
      referencedTable: $db.locationBasePlans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocationBasePlansTableFilterComposer(
            $db: $db,
            $table: $db.locationBasePlans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> shotsRefs(
    Expression<bool> Function($$ShotsTableFilterComposer f) f,
  ) {
    final $$ShotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shots,
      getReferencedColumn: (t) => t.sceneId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShotsTableFilterComposer(
            $db: $db,
            $table: $db.shots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ScenesTableOrderingComposer
    extends Composer<_$AppDatabase, $ScenesTable> {
  $$ScenesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locationCanonical => $composableBuilder(
    column: $table.locationCanonical,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locationPureName => $composableBuilder(
    column: $table.locationPureName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get intExt => $composableBuilder(
    column: $table.intExt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dayNight => $composableBuilder(
    column: $table.dayNight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locationColor => $composableBuilder(
    column: $table.locationColor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actionText => $composableBuilder(
    column: $table.actionText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sourceStartIndex => $composableBuilder(
    column: $table.sourceStartIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoNumbering => $composableBuilder(
    column: $table.autoNumbering,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LocationSitesTableOrderingComposer get locationSiteId {
    final $$LocationSitesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.locationSiteId,
      referencedTable: $db.locationSites,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocationSitesTableOrderingComposer(
            $db: $db,
            $table: $db.locationSites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LocationBasePlansTableOrderingComposer get locationId {
    final $$LocationBasePlansTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.locationId,
      referencedTable: $db.locationBasePlans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocationBasePlansTableOrderingComposer(
            $db: $db,
            $table: $db.locationBasePlans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ScenesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScenesTable> {
  $$ScenesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get number =>
      $composableBuilder(column: $table.number, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get locationCanonical => $composableBuilder(
    column: $table.locationCanonical,
    builder: (column) => column,
  );

  GeneratedColumn<String> get locationPureName => $composableBuilder(
    column: $table.locationPureName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get intExt =>
      $composableBuilder(column: $table.intExt, builder: (column) => column);

  GeneratedColumn<String> get dayNight =>
      $composableBuilder(column: $table.dayNight, builder: (column) => column);

  GeneratedColumn<String> get locationColor => $composableBuilder(
    column: $table.locationColor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get actionText => $composableBuilder(
    column: $table.actionText,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sourceStartIndex => $composableBuilder(
    column: $table.sourceStartIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get autoNumbering => $composableBuilder(
    column: $table.autoNumbering,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LocationSitesTableAnnotationComposer get locationSiteId {
    final $$LocationSitesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.locationSiteId,
      referencedTable: $db.locationSites,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocationSitesTableAnnotationComposer(
            $db: $db,
            $table: $db.locationSites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LocationBasePlansTableAnnotationComposer get locationId {
    final $$LocationBasePlansTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.locationId,
          referencedTable: $db.locationBasePlans,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LocationBasePlansTableAnnotationComposer(
                $db: $db,
                $table: $db.locationBasePlans,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  Expression<T> shotsRefs<T extends Object>(
    Expression<T> Function($$ShotsTableAnnotationComposer a) f,
  ) {
    final $$ShotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shots,
      getReferencedColumn: (t) => t.sceneId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShotsTableAnnotationComposer(
            $db: $db,
            $table: $db.shots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ScenesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScenesTable,
          Scene,
          $$ScenesTableFilterComposer,
          $$ScenesTableOrderingComposer,
          $$ScenesTableAnnotationComposer,
          $$ScenesTableCreateCompanionBuilder,
          $$ScenesTableUpdateCompanionBuilder,
          (Scene, $$ScenesTableReferences),
          Scene,
          PrefetchHooks Function({
            bool projectId,
            bool locationSiteId,
            bool locationId,
            bool shotsRefs,
          })
        > {
  $$ScenesTableTableManager(_$AppDatabase db, $ScenesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScenesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScenesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScenesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> projectId = const Value.absent(),
                Value<int> number = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> locationCanonical = const Value.absent(),
                Value<String> locationPureName = const Value.absent(),
                Value<int?> locationSiteId = const Value.absent(),
                Value<int?> locationId = const Value.absent(),
                Value<String> intExt = const Value.absent(),
                Value<String> dayNight = const Value.absent(),
                Value<String?> locationColor = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> actionText = const Value.absent(),
                Value<int?> sourceStartIndex = const Value.absent(),
                Value<int> durationMinutes = const Value.absent(),
                Value<bool> autoNumbering = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => ScenesCompanion(
                id: id,
                projectId: projectId,
                number: number,
                name: name,
                locationCanonical: locationCanonical,
                locationPureName: locationPureName,
                locationSiteId: locationSiteId,
                locationId: locationId,
                intExt: intExt,
                dayNight: dayNight,
                locationColor: locationColor,
                description: description,
                actionText: actionText,
                sourceStartIndex: sourceStartIndex,
                durationMinutes: durationMinutes,
                autoNumbering: autoNumbering,
                sortOrder: sortOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int projectId,
                required int number,
                required String name,
                required String locationCanonical,
                required String locationPureName,
                Value<int?> locationSiteId = const Value.absent(),
                Value<int?> locationId = const Value.absent(),
                Value<String> intExt = const Value.absent(),
                Value<String> dayNight = const Value.absent(),
                Value<String?> locationColor = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> actionText = const Value.absent(),
                Value<int?> sourceStartIndex = const Value.absent(),
                Value<int> durationMinutes = const Value.absent(),
                Value<bool> autoNumbering = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => ScenesCompanion.insert(
                id: id,
                projectId: projectId,
                number: number,
                name: name,
                locationCanonical: locationCanonical,
                locationPureName: locationPureName,
                locationSiteId: locationSiteId,
                locationId: locationId,
                intExt: intExt,
                dayNight: dayNight,
                locationColor: locationColor,
                description: description,
                actionText: actionText,
                sourceStartIndex: sourceStartIndex,
                durationMinutes: durationMinutes,
                autoNumbering: autoNumbering,
                sortOrder: sortOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$ScenesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                projectId = false,
                locationSiteId = false,
                locationId = false,
                shotsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [if (shotsRefs) db.shots],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (projectId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.projectId,
                                    referencedTable: $$ScenesTableReferences
                                        ._projectIdTable(db),
                                    referencedColumn: $$ScenesTableReferences
                                        ._projectIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (locationSiteId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.locationSiteId,
                                    referencedTable: $$ScenesTableReferences
                                        ._locationSiteIdTable(db),
                                    referencedColumn: $$ScenesTableReferences
                                        ._locationSiteIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (locationId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.locationId,
                                    referencedTable: $$ScenesTableReferences
                                        ._locationIdTable(db),
                                    referencedColumn: $$ScenesTableReferences
                                        ._locationIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (shotsRefs)
                        await $_getPrefetchedData<Scene, $ScenesTable, Shot>(
                          currentTable: table,
                          referencedTable: $$ScenesTableReferences
                              ._shotsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ScenesTableReferences(db, table, p0).shotsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sceneId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ScenesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScenesTable,
      Scene,
      $$ScenesTableFilterComposer,
      $$ScenesTableOrderingComposer,
      $$ScenesTableAnnotationComposer,
      $$ScenesTableCreateCompanionBuilder,
      $$ScenesTableUpdateCompanionBuilder,
      (Scene, $$ScenesTableReferences),
      Scene,
      PrefetchHooks Function({
        bool projectId,
        bool locationSiteId,
        bool locationId,
        bool shotsRefs,
      })
    >;
typedef $$ShotsTableCreateCompanionBuilder =
    ShotsCompanion Function({
      Value<int> id,
      required int sceneId,
      required int projectId,
      required int number,
      Value<String?> framing,
      Value<String?> lens,
      Value<String?> angle,
      Value<String?> movement,
      Value<String?> fStop,
      Value<String?> shutterAngle,
      Value<int?> fps,
      Value<String?> action,
      Value<String?> notes,
      Value<String?> notesHighlight,
      Value<String?> description,
      Value<String?> referenceImagePath,
      Value<String?> cameraPlanImagePath,
      Value<bool> autoNumbering,
      Value<int> sortOrder,
    });
typedef $$ShotsTableUpdateCompanionBuilder =
    ShotsCompanion Function({
      Value<int> id,
      Value<int> sceneId,
      Value<int> projectId,
      Value<int> number,
      Value<String?> framing,
      Value<String?> lens,
      Value<String?> angle,
      Value<String?> movement,
      Value<String?> fStop,
      Value<String?> shutterAngle,
      Value<int?> fps,
      Value<String?> action,
      Value<String?> notes,
      Value<String?> notesHighlight,
      Value<String?> description,
      Value<String?> referenceImagePath,
      Value<String?> cameraPlanImagePath,
      Value<bool> autoNumbering,
      Value<int> sortOrder,
    });

final class $$ShotsTableReferences
    extends BaseReferences<_$AppDatabase, $ShotsTable, Shot> {
  $$ShotsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ScenesTable _sceneIdTable(_$AppDatabase db) => db.scenes.createAlias(
    $_aliasNameGenerator(db.shots.sceneId, db.scenes.id),
  );

  $$ScenesTableProcessedTableManager get sceneId {
    final $_column = $_itemColumn<int>('scene_id')!;

    final manager = $$ScenesTableTableManager(
      $_db,
      $_db.scenes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sceneIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ProjectsTable _projectIdTable(_$AppDatabase db) => db.projects
      .createAlias($_aliasNameGenerator(db.shots.projectId, db.projects.id));

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<int>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ShotReferencesTable, List<ShotReference>>
  _shotReferencesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.shotReferences,
    aliasName: $_aliasNameGenerator(db.shots.id, db.shotReferences.shotId),
  );

  $$ShotReferencesTableProcessedTableManager get shotReferencesRefs {
    final manager = $$ShotReferencesTableTableManager(
      $_db,
      $_db.shotReferences,
    ).filter((f) => f.shotId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_shotReferencesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CameraPlanElementsTable, List<CameraPlanElement>>
  _cameraPlanElementsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.cameraPlanElements,
        aliasName: $_aliasNameGenerator(
          db.shots.id,
          db.cameraPlanElements.shotId,
        ),
      );

  $$CameraPlanElementsTableProcessedTableManager get cameraPlanElementsRefs {
    final manager = $$CameraPlanElementsTableTableManager(
      $_db,
      $_db.cameraPlanElements,
    ).filter((f) => f.shotId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _cameraPlanElementsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ShotsTableFilterComposer extends Composer<_$AppDatabase, $ShotsTable> {
  $$ShotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get framing => $composableBuilder(
    column: $table.framing,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lens => $composableBuilder(
    column: $table.lens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get angle => $composableBuilder(
    column: $table.angle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get movement => $composableBuilder(
    column: $table.movement,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fStop => $composableBuilder(
    column: $table.fStop,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shutterAngle => $composableBuilder(
    column: $table.shutterAngle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fps => $composableBuilder(
    column: $table.fps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notesHighlight => $composableBuilder(
    column: $table.notesHighlight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get referenceImagePath => $composableBuilder(
    column: $table.referenceImagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cameraPlanImagePath => $composableBuilder(
    column: $table.cameraPlanImagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get autoNumbering => $composableBuilder(
    column: $table.autoNumbering,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  $$ScenesTableFilterComposer get sceneId {
    final $$ScenesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sceneId,
      referencedTable: $db.scenes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScenesTableFilterComposer(
            $db: $db,
            $table: $db.scenes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> shotReferencesRefs(
    Expression<bool> Function($$ShotReferencesTableFilterComposer f) f,
  ) {
    final $$ShotReferencesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shotReferences,
      getReferencedColumn: (t) => t.shotId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShotReferencesTableFilterComposer(
            $db: $db,
            $table: $db.shotReferences,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> cameraPlanElementsRefs(
    Expression<bool> Function($$CameraPlanElementsTableFilterComposer f) f,
  ) {
    final $$CameraPlanElementsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cameraPlanElements,
      getReferencedColumn: (t) => t.shotId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CameraPlanElementsTableFilterComposer(
            $db: $db,
            $table: $db.cameraPlanElements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ShotsTableOrderingComposer
    extends Composer<_$AppDatabase, $ShotsTable> {
  $$ShotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get framing => $composableBuilder(
    column: $table.framing,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lens => $composableBuilder(
    column: $table.lens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get angle => $composableBuilder(
    column: $table.angle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get movement => $composableBuilder(
    column: $table.movement,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fStop => $composableBuilder(
    column: $table.fStop,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shutterAngle => $composableBuilder(
    column: $table.shutterAngle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fps => $composableBuilder(
    column: $table.fps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notesHighlight => $composableBuilder(
    column: $table.notesHighlight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get referenceImagePath => $composableBuilder(
    column: $table.referenceImagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cameraPlanImagePath => $composableBuilder(
    column: $table.cameraPlanImagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoNumbering => $composableBuilder(
    column: $table.autoNumbering,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  $$ScenesTableOrderingComposer get sceneId {
    final $$ScenesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sceneId,
      referencedTable: $db.scenes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScenesTableOrderingComposer(
            $db: $db,
            $table: $db.scenes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShotsTable> {
  $$ShotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get number =>
      $composableBuilder(column: $table.number, builder: (column) => column);

  GeneratedColumn<String> get framing =>
      $composableBuilder(column: $table.framing, builder: (column) => column);

  GeneratedColumn<String> get lens =>
      $composableBuilder(column: $table.lens, builder: (column) => column);

  GeneratedColumn<String> get angle =>
      $composableBuilder(column: $table.angle, builder: (column) => column);

  GeneratedColumn<String> get movement =>
      $composableBuilder(column: $table.movement, builder: (column) => column);

  GeneratedColumn<String> get fStop =>
      $composableBuilder(column: $table.fStop, builder: (column) => column);

  GeneratedColumn<String> get shutterAngle => $composableBuilder(
    column: $table.shutterAngle,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fps =>
      $composableBuilder(column: $table.fps, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get notesHighlight => $composableBuilder(
    column: $table.notesHighlight,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get referenceImagePath => $composableBuilder(
    column: $table.referenceImagePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cameraPlanImagePath => $composableBuilder(
    column: $table.cameraPlanImagePath,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get autoNumbering => $composableBuilder(
    column: $table.autoNumbering,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  $$ScenesTableAnnotationComposer get sceneId {
    final $$ScenesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sceneId,
      referencedTable: $db.scenes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScenesTableAnnotationComposer(
            $db: $db,
            $table: $db.scenes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> shotReferencesRefs<T extends Object>(
    Expression<T> Function($$ShotReferencesTableAnnotationComposer a) f,
  ) {
    final $$ShotReferencesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shotReferences,
      getReferencedColumn: (t) => t.shotId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShotReferencesTableAnnotationComposer(
            $db: $db,
            $table: $db.shotReferences,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> cameraPlanElementsRefs<T extends Object>(
    Expression<T> Function($$CameraPlanElementsTableAnnotationComposer a) f,
  ) {
    final $$CameraPlanElementsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.cameraPlanElements,
          getReferencedColumn: (t) => t.shotId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CameraPlanElementsTableAnnotationComposer(
                $db: $db,
                $table: $db.cameraPlanElements,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ShotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ShotsTable,
          Shot,
          $$ShotsTableFilterComposer,
          $$ShotsTableOrderingComposer,
          $$ShotsTableAnnotationComposer,
          $$ShotsTableCreateCompanionBuilder,
          $$ShotsTableUpdateCompanionBuilder,
          (Shot, $$ShotsTableReferences),
          Shot,
          PrefetchHooks Function({
            bool sceneId,
            bool projectId,
            bool shotReferencesRefs,
            bool cameraPlanElementsRefs,
          })
        > {
  $$ShotsTableTableManager(_$AppDatabase db, $ShotsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> sceneId = const Value.absent(),
                Value<int> projectId = const Value.absent(),
                Value<int> number = const Value.absent(),
                Value<String?> framing = const Value.absent(),
                Value<String?> lens = const Value.absent(),
                Value<String?> angle = const Value.absent(),
                Value<String?> movement = const Value.absent(),
                Value<String?> fStop = const Value.absent(),
                Value<String?> shutterAngle = const Value.absent(),
                Value<int?> fps = const Value.absent(),
                Value<String?> action = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> notesHighlight = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> referenceImagePath = const Value.absent(),
                Value<String?> cameraPlanImagePath = const Value.absent(),
                Value<bool> autoNumbering = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => ShotsCompanion(
                id: id,
                sceneId: sceneId,
                projectId: projectId,
                number: number,
                framing: framing,
                lens: lens,
                angle: angle,
                movement: movement,
                fStop: fStop,
                shutterAngle: shutterAngle,
                fps: fps,
                action: action,
                notes: notes,
                notesHighlight: notesHighlight,
                description: description,
                referenceImagePath: referenceImagePath,
                cameraPlanImagePath: cameraPlanImagePath,
                autoNumbering: autoNumbering,
                sortOrder: sortOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int sceneId,
                required int projectId,
                required int number,
                Value<String?> framing = const Value.absent(),
                Value<String?> lens = const Value.absent(),
                Value<String?> angle = const Value.absent(),
                Value<String?> movement = const Value.absent(),
                Value<String?> fStop = const Value.absent(),
                Value<String?> shutterAngle = const Value.absent(),
                Value<int?> fps = const Value.absent(),
                Value<String?> action = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> notesHighlight = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> referenceImagePath = const Value.absent(),
                Value<String?> cameraPlanImagePath = const Value.absent(),
                Value<bool> autoNumbering = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => ShotsCompanion.insert(
                id: id,
                sceneId: sceneId,
                projectId: projectId,
                number: number,
                framing: framing,
                lens: lens,
                angle: angle,
                movement: movement,
                fStop: fStop,
                shutterAngle: shutterAngle,
                fps: fps,
                action: action,
                notes: notes,
                notesHighlight: notesHighlight,
                description: description,
                referenceImagePath: referenceImagePath,
                cameraPlanImagePath: cameraPlanImagePath,
                autoNumbering: autoNumbering,
                sortOrder: sortOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$ShotsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                sceneId = false,
                projectId = false,
                shotReferencesRefs = false,
                cameraPlanElementsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (shotReferencesRefs) db.shotReferences,
                    if (cameraPlanElementsRefs) db.cameraPlanElements,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (sceneId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.sceneId,
                                    referencedTable: $$ShotsTableReferences
                                        ._sceneIdTable(db),
                                    referencedColumn: $$ShotsTableReferences
                                        ._sceneIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (projectId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.projectId,
                                    referencedTable: $$ShotsTableReferences
                                        ._projectIdTable(db),
                                    referencedColumn: $$ShotsTableReferences
                                        ._projectIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (shotReferencesRefs)
                        await $_getPrefetchedData<
                          Shot,
                          $ShotsTable,
                          ShotReference
                        >(
                          currentTable: table,
                          referencedTable: $$ShotsTableReferences
                              ._shotReferencesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ShotsTableReferences(
                                db,
                                table,
                                p0,
                              ).shotReferencesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.shotId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (cameraPlanElementsRefs)
                        await $_getPrefetchedData<
                          Shot,
                          $ShotsTable,
                          CameraPlanElement
                        >(
                          currentTable: table,
                          referencedTable: $$ShotsTableReferences
                              ._cameraPlanElementsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ShotsTableReferences(
                                db,
                                table,
                                p0,
                              ).cameraPlanElementsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.shotId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ShotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ShotsTable,
      Shot,
      $$ShotsTableFilterComposer,
      $$ShotsTableOrderingComposer,
      $$ShotsTableAnnotationComposer,
      $$ShotsTableCreateCompanionBuilder,
      $$ShotsTableUpdateCompanionBuilder,
      (Shot, $$ShotsTableReferences),
      Shot,
      PrefetchHooks Function({
        bool sceneId,
        bool projectId,
        bool shotReferencesRefs,
        bool cameraPlanElementsRefs,
      })
    >;
typedef $$ShotReferencesTableCreateCompanionBuilder =
    ShotReferencesCompanion Function({
      Value<int> id,
      required int shotId,
      required String imagePath,
      Value<String> source,
      Value<int> sortOrder,
    });
typedef $$ShotReferencesTableUpdateCompanionBuilder =
    ShotReferencesCompanion Function({
      Value<int> id,
      Value<int> shotId,
      Value<String> imagePath,
      Value<String> source,
      Value<int> sortOrder,
    });

final class $$ShotReferencesTableReferences
    extends BaseReferences<_$AppDatabase, $ShotReferencesTable, ShotReference> {
  $$ShotReferencesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ShotsTable _shotIdTable(_$AppDatabase db) => db.shots.createAlias(
    $_aliasNameGenerator(db.shotReferences.shotId, db.shots.id),
  );

  $$ShotsTableProcessedTableManager get shotId {
    final $_column = $_itemColumn<int>('shot_id')!;

    final manager = $$ShotsTableTableManager(
      $_db,
      $_db.shots,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_shotIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ShotReferencesTableFilterComposer
    extends Composer<_$AppDatabase, $ShotReferencesTable> {
  $$ShotReferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  $$ShotsTableFilterComposer get shotId {
    final $$ShotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shotId,
      referencedTable: $db.shots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShotsTableFilterComposer(
            $db: $db,
            $table: $db.shots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShotReferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $ShotReferencesTable> {
  $$ShotReferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  $$ShotsTableOrderingComposer get shotId {
    final $$ShotsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shotId,
      referencedTable: $db.shots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShotsTableOrderingComposer(
            $db: $db,
            $table: $db.shots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShotReferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShotReferencesTable> {
  $$ShotReferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  $$ShotsTableAnnotationComposer get shotId {
    final $$ShotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shotId,
      referencedTable: $db.shots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShotsTableAnnotationComposer(
            $db: $db,
            $table: $db.shots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShotReferencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ShotReferencesTable,
          ShotReference,
          $$ShotReferencesTableFilterComposer,
          $$ShotReferencesTableOrderingComposer,
          $$ShotReferencesTableAnnotationComposer,
          $$ShotReferencesTableCreateCompanionBuilder,
          $$ShotReferencesTableUpdateCompanionBuilder,
          (ShotReference, $$ShotReferencesTableReferences),
          ShotReference,
          PrefetchHooks Function({bool shotId})
        > {
  $$ShotReferencesTableTableManager(
    _$AppDatabase db,
    $ShotReferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShotReferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShotReferencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShotReferencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> shotId = const Value.absent(),
                Value<String> imagePath = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => ShotReferencesCompanion(
                id: id,
                shotId: shotId,
                imagePath: imagePath,
                source: source,
                sortOrder: sortOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int shotId,
                required String imagePath,
                Value<String> source = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => ShotReferencesCompanion.insert(
                id: id,
                shotId: shotId,
                imagePath: imagePath,
                source: source,
                sortOrder: sortOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ShotReferencesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({shotId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (shotId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.shotId,
                                referencedTable: $$ShotReferencesTableReferences
                                    ._shotIdTable(db),
                                referencedColumn:
                                    $$ShotReferencesTableReferences
                                        ._shotIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ShotReferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ShotReferencesTable,
      ShotReference,
      $$ShotReferencesTableFilterComposer,
      $$ShotReferencesTableOrderingComposer,
      $$ShotReferencesTableAnnotationComposer,
      $$ShotReferencesTableCreateCompanionBuilder,
      $$ShotReferencesTableUpdateCompanionBuilder,
      (ShotReference, $$ShotReferencesTableReferences),
      ShotReference,
      PrefetchHooks Function({bool shotId})
    >;
typedef $$CameraPlanElementsTableCreateCompanionBuilder =
    CameraPlanElementsCompanion Function({
      Value<int> id,
      required int shotId,
      required String type,
      Value<double> x,
      Value<double> y,
      Value<double> rotation,
      Value<String?> label,
      Value<String?> color,
      Value<String?> cameraStabilization,
      Value<String?> cameraLens,
      Value<String> cameraLetter,
      Value<int> cameraNumber,
      Value<String?> lightType,
      Value<bool> lukaCompatible,
      Value<String?> lukaFixtureId,
      Value<String?> externalMappingJson,
      Value<int> sortOrder,
    });
typedef $$CameraPlanElementsTableUpdateCompanionBuilder =
    CameraPlanElementsCompanion Function({
      Value<int> id,
      Value<int> shotId,
      Value<String> type,
      Value<double> x,
      Value<double> y,
      Value<double> rotation,
      Value<String?> label,
      Value<String?> color,
      Value<String?> cameraStabilization,
      Value<String?> cameraLens,
      Value<String> cameraLetter,
      Value<int> cameraNumber,
      Value<String?> lightType,
      Value<bool> lukaCompatible,
      Value<String?> lukaFixtureId,
      Value<String?> externalMappingJson,
      Value<int> sortOrder,
    });

final class $$CameraPlanElementsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $CameraPlanElementsTable,
          CameraPlanElement
        > {
  $$CameraPlanElementsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ShotsTable _shotIdTable(_$AppDatabase db) => db.shots.createAlias(
    $_aliasNameGenerator(db.cameraPlanElements.shotId, db.shots.id),
  );

  $$ShotsTableProcessedTableManager get shotId {
    final $_column = $_itemColumn<int>('shot_id')!;

    final manager = $$ShotsTableTableManager(
      $_db,
      $_db.shots,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_shotIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$CameraPathPointsTable, List<CameraPathPoint>>
  _cameraPathPointsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.cameraPathPoints,
    aliasName: $_aliasNameGenerator(
      db.cameraPlanElements.id,
      db.cameraPathPoints.elementId,
    ),
  );

  $$CameraPathPointsTableProcessedTableManager get cameraPathPointsRefs {
    final manager = $$CameraPathPointsTableTableManager(
      $_db,
      $_db.cameraPathPoints,
    ).filter((f) => f.elementId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _cameraPathPointsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CameraPlanElementsTableFilterComposer
    extends Composer<_$AppDatabase, $CameraPlanElementsTable> {
  $$CameraPlanElementsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rotation => $composableBuilder(
    column: $table.rotation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cameraStabilization => $composableBuilder(
    column: $table.cameraStabilization,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cameraLens => $composableBuilder(
    column: $table.cameraLens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cameraLetter => $composableBuilder(
    column: $table.cameraLetter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cameraNumber => $composableBuilder(
    column: $table.cameraNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lightType => $composableBuilder(
    column: $table.lightType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get lukaCompatible => $composableBuilder(
    column: $table.lukaCompatible,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lukaFixtureId => $composableBuilder(
    column: $table.lukaFixtureId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get externalMappingJson => $composableBuilder(
    column: $table.externalMappingJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  $$ShotsTableFilterComposer get shotId {
    final $$ShotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shotId,
      referencedTable: $db.shots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShotsTableFilterComposer(
            $db: $db,
            $table: $db.shots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> cameraPathPointsRefs(
    Expression<bool> Function($$CameraPathPointsTableFilterComposer f) f,
  ) {
    final $$CameraPathPointsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cameraPathPoints,
      getReferencedColumn: (t) => t.elementId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CameraPathPointsTableFilterComposer(
            $db: $db,
            $table: $db.cameraPathPoints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CameraPlanElementsTableOrderingComposer
    extends Composer<_$AppDatabase, $CameraPlanElementsTable> {
  $$CameraPlanElementsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rotation => $composableBuilder(
    column: $table.rotation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cameraStabilization => $composableBuilder(
    column: $table.cameraStabilization,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cameraLens => $composableBuilder(
    column: $table.cameraLens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cameraLetter => $composableBuilder(
    column: $table.cameraLetter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cameraNumber => $composableBuilder(
    column: $table.cameraNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lightType => $composableBuilder(
    column: $table.lightType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get lukaCompatible => $composableBuilder(
    column: $table.lukaCompatible,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lukaFixtureId => $composableBuilder(
    column: $table.lukaFixtureId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get externalMappingJson => $composableBuilder(
    column: $table.externalMappingJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  $$ShotsTableOrderingComposer get shotId {
    final $$ShotsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shotId,
      referencedTable: $db.shots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShotsTableOrderingComposer(
            $db: $db,
            $table: $db.shots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CameraPlanElementsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CameraPlanElementsTable> {
  $$CameraPlanElementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<double> get x =>
      $composableBuilder(column: $table.x, builder: (column) => column);

  GeneratedColumn<double> get y =>
      $composableBuilder(column: $table.y, builder: (column) => column);

  GeneratedColumn<double> get rotation =>
      $composableBuilder(column: $table.rotation, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get cameraStabilization => $composableBuilder(
    column: $table.cameraStabilization,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cameraLens => $composableBuilder(
    column: $table.cameraLens,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cameraLetter => $composableBuilder(
    column: $table.cameraLetter,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cameraNumber => $composableBuilder(
    column: $table.cameraNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lightType =>
      $composableBuilder(column: $table.lightType, builder: (column) => column);

  GeneratedColumn<bool> get lukaCompatible => $composableBuilder(
    column: $table.lukaCompatible,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lukaFixtureId => $composableBuilder(
    column: $table.lukaFixtureId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get externalMappingJson => $composableBuilder(
    column: $table.externalMappingJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  $$ShotsTableAnnotationComposer get shotId {
    final $$ShotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shotId,
      referencedTable: $db.shots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShotsTableAnnotationComposer(
            $db: $db,
            $table: $db.shots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> cameraPathPointsRefs<T extends Object>(
    Expression<T> Function($$CameraPathPointsTableAnnotationComposer a) f,
  ) {
    final $$CameraPathPointsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cameraPathPoints,
      getReferencedColumn: (t) => t.elementId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CameraPathPointsTableAnnotationComposer(
            $db: $db,
            $table: $db.cameraPathPoints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CameraPlanElementsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CameraPlanElementsTable,
          CameraPlanElement,
          $$CameraPlanElementsTableFilterComposer,
          $$CameraPlanElementsTableOrderingComposer,
          $$CameraPlanElementsTableAnnotationComposer,
          $$CameraPlanElementsTableCreateCompanionBuilder,
          $$CameraPlanElementsTableUpdateCompanionBuilder,
          (CameraPlanElement, $$CameraPlanElementsTableReferences),
          CameraPlanElement,
          PrefetchHooks Function({bool shotId, bool cameraPathPointsRefs})
        > {
  $$CameraPlanElementsTableTableManager(
    _$AppDatabase db,
    $CameraPlanElementsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CameraPlanElementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CameraPlanElementsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CameraPlanElementsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> shotId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<double> x = const Value.absent(),
                Value<double> y = const Value.absent(),
                Value<double> rotation = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<String?> cameraStabilization = const Value.absent(),
                Value<String?> cameraLens = const Value.absent(),
                Value<String> cameraLetter = const Value.absent(),
                Value<int> cameraNumber = const Value.absent(),
                Value<String?> lightType = const Value.absent(),
                Value<bool> lukaCompatible = const Value.absent(),
                Value<String?> lukaFixtureId = const Value.absent(),
                Value<String?> externalMappingJson = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => CameraPlanElementsCompanion(
                id: id,
                shotId: shotId,
                type: type,
                x: x,
                y: y,
                rotation: rotation,
                label: label,
                color: color,
                cameraStabilization: cameraStabilization,
                cameraLens: cameraLens,
                cameraLetter: cameraLetter,
                cameraNumber: cameraNumber,
                lightType: lightType,
                lukaCompatible: lukaCompatible,
                lukaFixtureId: lukaFixtureId,
                externalMappingJson: externalMappingJson,
                sortOrder: sortOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int shotId,
                required String type,
                Value<double> x = const Value.absent(),
                Value<double> y = const Value.absent(),
                Value<double> rotation = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<String?> cameraStabilization = const Value.absent(),
                Value<String?> cameraLens = const Value.absent(),
                Value<String> cameraLetter = const Value.absent(),
                Value<int> cameraNumber = const Value.absent(),
                Value<String?> lightType = const Value.absent(),
                Value<bool> lukaCompatible = const Value.absent(),
                Value<String?> lukaFixtureId = const Value.absent(),
                Value<String?> externalMappingJson = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => CameraPlanElementsCompanion.insert(
                id: id,
                shotId: shotId,
                type: type,
                x: x,
                y: y,
                rotation: rotation,
                label: label,
                color: color,
                cameraStabilization: cameraStabilization,
                cameraLens: cameraLens,
                cameraLetter: cameraLetter,
                cameraNumber: cameraNumber,
                lightType: lightType,
                lukaCompatible: lukaCompatible,
                lukaFixtureId: lukaFixtureId,
                externalMappingJson: externalMappingJson,
                sortOrder: sortOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CameraPlanElementsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({shotId = false, cameraPathPointsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (cameraPathPointsRefs) db.cameraPathPoints,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (shotId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.shotId,
                                    referencedTable:
                                        $$CameraPlanElementsTableReferences
                                            ._shotIdTable(db),
                                    referencedColumn:
                                        $$CameraPlanElementsTableReferences
                                            ._shotIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (cameraPathPointsRefs)
                        await $_getPrefetchedData<
                          CameraPlanElement,
                          $CameraPlanElementsTable,
                          CameraPathPoint
                        >(
                          currentTable: table,
                          referencedTable: $$CameraPlanElementsTableReferences
                              ._cameraPathPointsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CameraPlanElementsTableReferences(
                                db,
                                table,
                                p0,
                              ).cameraPathPointsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.elementId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CameraPlanElementsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CameraPlanElementsTable,
      CameraPlanElement,
      $$CameraPlanElementsTableFilterComposer,
      $$CameraPlanElementsTableOrderingComposer,
      $$CameraPlanElementsTableAnnotationComposer,
      $$CameraPlanElementsTableCreateCompanionBuilder,
      $$CameraPlanElementsTableUpdateCompanionBuilder,
      (CameraPlanElement, $$CameraPlanElementsTableReferences),
      CameraPlanElement,
      PrefetchHooks Function({bool shotId, bool cameraPathPointsRefs})
    >;
typedef $$CameraPathPointsTableCreateCompanionBuilder =
    CameraPathPointsCompanion Function({
      Value<int> id,
      required int elementId,
      required int pointNumber,
      required double x,
      required double y,
    });
typedef $$CameraPathPointsTableUpdateCompanionBuilder =
    CameraPathPointsCompanion Function({
      Value<int> id,
      Value<int> elementId,
      Value<int> pointNumber,
      Value<double> x,
      Value<double> y,
    });

final class $$CameraPathPointsTableReferences
    extends
        BaseReferences<_$AppDatabase, $CameraPathPointsTable, CameraPathPoint> {
  $$CameraPathPointsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CameraPlanElementsTable _elementIdTable(_$AppDatabase db) =>
      db.cameraPlanElements.createAlias(
        $_aliasNameGenerator(
          db.cameraPathPoints.elementId,
          db.cameraPlanElements.id,
        ),
      );

  $$CameraPlanElementsTableProcessedTableManager get elementId {
    final $_column = $_itemColumn<int>('element_id')!;

    final manager = $$CameraPlanElementsTableTableManager(
      $_db,
      $_db.cameraPlanElements,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_elementIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CameraPathPointsTableFilterComposer
    extends Composer<_$AppDatabase, $CameraPathPointsTable> {
  $$CameraPathPointsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pointNumber => $composableBuilder(
    column: $table.pointNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnFilters(column),
  );

  $$CameraPlanElementsTableFilterComposer get elementId {
    final $$CameraPlanElementsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.elementId,
      referencedTable: $db.cameraPlanElements,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CameraPlanElementsTableFilterComposer(
            $db: $db,
            $table: $db.cameraPlanElements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CameraPathPointsTableOrderingComposer
    extends Composer<_$AppDatabase, $CameraPathPointsTable> {
  $$CameraPathPointsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pointNumber => $composableBuilder(
    column: $table.pointNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnOrderings(column),
  );

  $$CameraPlanElementsTableOrderingComposer get elementId {
    final $$CameraPlanElementsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.elementId,
      referencedTable: $db.cameraPlanElements,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CameraPlanElementsTableOrderingComposer(
            $db: $db,
            $table: $db.cameraPlanElements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CameraPathPointsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CameraPathPointsTable> {
  $$CameraPathPointsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get pointNumber => $composableBuilder(
    column: $table.pointNumber,
    builder: (column) => column,
  );

  GeneratedColumn<double> get x =>
      $composableBuilder(column: $table.x, builder: (column) => column);

  GeneratedColumn<double> get y =>
      $composableBuilder(column: $table.y, builder: (column) => column);

  $$CameraPlanElementsTableAnnotationComposer get elementId {
    final $$CameraPlanElementsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.elementId,
          referencedTable: $db.cameraPlanElements,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CameraPlanElementsTableAnnotationComposer(
                $db: $db,
                $table: $db.cameraPlanElements,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$CameraPathPointsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CameraPathPointsTable,
          CameraPathPoint,
          $$CameraPathPointsTableFilterComposer,
          $$CameraPathPointsTableOrderingComposer,
          $$CameraPathPointsTableAnnotationComposer,
          $$CameraPathPointsTableCreateCompanionBuilder,
          $$CameraPathPointsTableUpdateCompanionBuilder,
          (CameraPathPoint, $$CameraPathPointsTableReferences),
          CameraPathPoint,
          PrefetchHooks Function({bool elementId})
        > {
  $$CameraPathPointsTableTableManager(
    _$AppDatabase db,
    $CameraPathPointsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CameraPathPointsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CameraPathPointsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CameraPathPointsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> elementId = const Value.absent(),
                Value<int> pointNumber = const Value.absent(),
                Value<double> x = const Value.absent(),
                Value<double> y = const Value.absent(),
              }) => CameraPathPointsCompanion(
                id: id,
                elementId: elementId,
                pointNumber: pointNumber,
                x: x,
                y: y,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int elementId,
                required int pointNumber,
                required double x,
                required double y,
              }) => CameraPathPointsCompanion.insert(
                id: id,
                elementId: elementId,
                pointNumber: pointNumber,
                x: x,
                y: y,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CameraPathPointsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({elementId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (elementId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.elementId,
                                referencedTable:
                                    $$CameraPathPointsTableReferences
                                        ._elementIdTable(db),
                                referencedColumn:
                                    $$CameraPathPointsTableReferences
                                        ._elementIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CameraPathPointsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CameraPathPointsTable,
      CameraPathPoint,
      $$CameraPathPointsTableFilterComposer,
      $$CameraPathPointsTableOrderingComposer,
      $$CameraPathPointsTableAnnotationComposer,
      $$CameraPathPointsTableCreateCompanionBuilder,
      $$CameraPathPointsTableUpdateCompanionBuilder,
      (CameraPathPoint, $$CameraPathPointsTableReferences),
      CameraPathPoint,
      PrefetchHooks Function({bool elementId})
    >;
typedef $$LocationImagesTableCreateCompanionBuilder =
    LocationImagesCompanion Function({
      Value<int> id,
      required int locationId,
      required String imagePath,
      Value<String?> caption,
      Value<String> kind,
      Value<String?> timeOfDay,
      Value<int> sortOrder,
    });
typedef $$LocationImagesTableUpdateCompanionBuilder =
    LocationImagesCompanion Function({
      Value<int> id,
      Value<int> locationId,
      Value<String> imagePath,
      Value<String?> caption,
      Value<String> kind,
      Value<String?> timeOfDay,
      Value<int> sortOrder,
    });

final class $$LocationImagesTableReferences
    extends BaseReferences<_$AppDatabase, $LocationImagesTable, LocationImage> {
  $$LocationImagesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LocationBasePlansTable _locationIdTable(_$AppDatabase db) =>
      db.locationBasePlans.createAlias(
        $_aliasNameGenerator(
          db.locationImages.locationId,
          db.locationBasePlans.id,
        ),
      );

  $$LocationBasePlansTableProcessedTableManager get locationId {
    final $_column = $_itemColumn<int>('location_id')!;

    final manager = $$LocationBasePlansTableTableManager(
      $_db,
      $_db.locationBasePlans,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_locationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LocationImagesTableFilterComposer
    extends Composer<_$AppDatabase, $LocationImagesTable> {
  $$LocationImagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get caption => $composableBuilder(
    column: $table.caption,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timeOfDay => $composableBuilder(
    column: $table.timeOfDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  $$LocationBasePlansTableFilterComposer get locationId {
    final $$LocationBasePlansTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.locationId,
      referencedTable: $db.locationBasePlans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocationBasePlansTableFilterComposer(
            $db: $db,
            $table: $db.locationBasePlans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocationImagesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocationImagesTable> {
  $$LocationImagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get caption => $composableBuilder(
    column: $table.caption,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timeOfDay => $composableBuilder(
    column: $table.timeOfDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  $$LocationBasePlansTableOrderingComposer get locationId {
    final $$LocationBasePlansTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.locationId,
      referencedTable: $db.locationBasePlans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocationBasePlansTableOrderingComposer(
            $db: $db,
            $table: $db.locationBasePlans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocationImagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocationImagesTable> {
  $$LocationImagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<String> get caption =>
      $composableBuilder(column: $table.caption, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get timeOfDay =>
      $composableBuilder(column: $table.timeOfDay, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  $$LocationBasePlansTableAnnotationComposer get locationId {
    final $$LocationBasePlansTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.locationId,
          referencedTable: $db.locationBasePlans,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LocationBasePlansTableAnnotationComposer(
                $db: $db,
                $table: $db.locationBasePlans,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$LocationImagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocationImagesTable,
          LocationImage,
          $$LocationImagesTableFilterComposer,
          $$LocationImagesTableOrderingComposer,
          $$LocationImagesTableAnnotationComposer,
          $$LocationImagesTableCreateCompanionBuilder,
          $$LocationImagesTableUpdateCompanionBuilder,
          (LocationImage, $$LocationImagesTableReferences),
          LocationImage,
          PrefetchHooks Function({bool locationId})
        > {
  $$LocationImagesTableTableManager(
    _$AppDatabase db,
    $LocationImagesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocationImagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocationImagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocationImagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> locationId = const Value.absent(),
                Value<String> imagePath = const Value.absent(),
                Value<String?> caption = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> timeOfDay = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => LocationImagesCompanion(
                id: id,
                locationId: locationId,
                imagePath: imagePath,
                caption: caption,
                kind: kind,
                timeOfDay: timeOfDay,
                sortOrder: sortOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int locationId,
                required String imagePath,
                Value<String?> caption = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> timeOfDay = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => LocationImagesCompanion.insert(
                id: id,
                locationId: locationId,
                imagePath: imagePath,
                caption: caption,
                kind: kind,
                timeOfDay: timeOfDay,
                sortOrder: sortOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LocationImagesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({locationId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (locationId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.locationId,
                                referencedTable: $$LocationImagesTableReferences
                                    ._locationIdTable(db),
                                referencedColumn:
                                    $$LocationImagesTableReferences
                                        ._locationIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LocationImagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocationImagesTable,
      LocationImage,
      $$LocationImagesTableFilterComposer,
      $$LocationImagesTableOrderingComposer,
      $$LocationImagesTableAnnotationComposer,
      $$LocationImagesTableCreateCompanionBuilder,
      $$LocationImagesTableUpdateCompanionBuilder,
      (LocationImage, $$LocationImagesTableReferences),
      LocationImage,
      PrefetchHooks Function({bool locationId})
    >;
typedef $$SiteImagesTableCreateCompanionBuilder =
    SiteImagesCompanion Function({
      Value<int> id,
      required int siteId,
      required String imagePath,
      Value<String?> caption,
      Value<String> kind,
      Value<String?> timeOfDay,
      Value<int> sortOrder,
    });
typedef $$SiteImagesTableUpdateCompanionBuilder =
    SiteImagesCompanion Function({
      Value<int> id,
      Value<int> siteId,
      Value<String> imagePath,
      Value<String?> caption,
      Value<String> kind,
      Value<String?> timeOfDay,
      Value<int> sortOrder,
    });

final class $$SiteImagesTableReferences
    extends BaseReferences<_$AppDatabase, $SiteImagesTable, SiteImage> {
  $$SiteImagesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LocationSitesTable _siteIdTable(_$AppDatabase db) =>
      db.locationSites.createAlias(
        $_aliasNameGenerator(db.siteImages.siteId, db.locationSites.id),
      );

  $$LocationSitesTableProcessedTableManager get siteId {
    final $_column = $_itemColumn<int>('site_id')!;

    final manager = $$LocationSitesTableTableManager(
      $_db,
      $_db.locationSites,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_siteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SiteImagesTableFilterComposer
    extends Composer<_$AppDatabase, $SiteImagesTable> {
  $$SiteImagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get caption => $composableBuilder(
    column: $table.caption,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timeOfDay => $composableBuilder(
    column: $table.timeOfDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  $$LocationSitesTableFilterComposer get siteId {
    final $$LocationSitesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.siteId,
      referencedTable: $db.locationSites,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocationSitesTableFilterComposer(
            $db: $db,
            $table: $db.locationSites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SiteImagesTableOrderingComposer
    extends Composer<_$AppDatabase, $SiteImagesTable> {
  $$SiteImagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get caption => $composableBuilder(
    column: $table.caption,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timeOfDay => $composableBuilder(
    column: $table.timeOfDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  $$LocationSitesTableOrderingComposer get siteId {
    final $$LocationSitesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.siteId,
      referencedTable: $db.locationSites,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocationSitesTableOrderingComposer(
            $db: $db,
            $table: $db.locationSites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SiteImagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SiteImagesTable> {
  $$SiteImagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<String> get caption =>
      $composableBuilder(column: $table.caption, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get timeOfDay =>
      $composableBuilder(column: $table.timeOfDay, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  $$LocationSitesTableAnnotationComposer get siteId {
    final $$LocationSitesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.siteId,
      referencedTable: $db.locationSites,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocationSitesTableAnnotationComposer(
            $db: $db,
            $table: $db.locationSites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SiteImagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SiteImagesTable,
          SiteImage,
          $$SiteImagesTableFilterComposer,
          $$SiteImagesTableOrderingComposer,
          $$SiteImagesTableAnnotationComposer,
          $$SiteImagesTableCreateCompanionBuilder,
          $$SiteImagesTableUpdateCompanionBuilder,
          (SiteImage, $$SiteImagesTableReferences),
          SiteImage,
          PrefetchHooks Function({bool siteId})
        > {
  $$SiteImagesTableTableManager(_$AppDatabase db, $SiteImagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SiteImagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SiteImagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SiteImagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> siteId = const Value.absent(),
                Value<String> imagePath = const Value.absent(),
                Value<String?> caption = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> timeOfDay = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => SiteImagesCompanion(
                id: id,
                siteId: siteId,
                imagePath: imagePath,
                caption: caption,
                kind: kind,
                timeOfDay: timeOfDay,
                sortOrder: sortOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int siteId,
                required String imagePath,
                Value<String?> caption = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> timeOfDay = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => SiteImagesCompanion.insert(
                id: id,
                siteId: siteId,
                imagePath: imagePath,
                caption: caption,
                kind: kind,
                timeOfDay: timeOfDay,
                sortOrder: sortOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SiteImagesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({siteId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (siteId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.siteId,
                                referencedTable: $$SiteImagesTableReferences
                                    ._siteIdTable(db),
                                referencedColumn: $$SiteImagesTableReferences
                                    ._siteIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SiteImagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SiteImagesTable,
      SiteImage,
      $$SiteImagesTableFilterComposer,
      $$SiteImagesTableOrderingComposer,
      $$SiteImagesTableAnnotationComposer,
      $$SiteImagesTableCreateCompanionBuilder,
      $$SiteImagesTableUpdateCompanionBuilder,
      (SiteImage, $$SiteImagesTableReferences),
      SiteImage,
      PrefetchHooks Function({bool siteId})
    >;
typedef $$CamerasTableCreateCompanionBuilder =
    CamerasCompanion Function({
      Value<int> id,
      required String brand,
      required String model,
      required double sensorWidthMm,
      required double sensorHeightMm,
      Value<String?> recordingFormats,
      Value<String?> notes,
    });
typedef $$CamerasTableUpdateCompanionBuilder =
    CamerasCompanion Function({
      Value<int> id,
      Value<String> brand,
      Value<String> model,
      Value<double> sensorWidthMm,
      Value<double> sensorHeightMm,
      Value<String?> recordingFormats,
      Value<String?> notes,
    });

class $$CamerasTableFilterComposer
    extends Composer<_$AppDatabase, $CamerasTable> {
  $$CamerasTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get brand => $composableBuilder(
    column: $table.brand,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sensorWidthMm => $composableBuilder(
    column: $table.sensorWidthMm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sensorHeightMm => $composableBuilder(
    column: $table.sensorHeightMm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordingFormats => $composableBuilder(
    column: $table.recordingFormats,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CamerasTableOrderingComposer
    extends Composer<_$AppDatabase, $CamerasTable> {
  $$CamerasTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get brand => $composableBuilder(
    column: $table.brand,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sensorWidthMm => $composableBuilder(
    column: $table.sensorWidthMm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sensorHeightMm => $composableBuilder(
    column: $table.sensorHeightMm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordingFormats => $composableBuilder(
    column: $table.recordingFormats,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CamerasTableAnnotationComposer
    extends Composer<_$AppDatabase, $CamerasTable> {
  $$CamerasTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get brand =>
      $composableBuilder(column: $table.brand, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<double> get sensorWidthMm => $composableBuilder(
    column: $table.sensorWidthMm,
    builder: (column) => column,
  );

  GeneratedColumn<double> get sensorHeightMm => $composableBuilder(
    column: $table.sensorHeightMm,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recordingFormats => $composableBuilder(
    column: $table.recordingFormats,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);
}

class $$CamerasTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CamerasTable,
          Camera,
          $$CamerasTableFilterComposer,
          $$CamerasTableOrderingComposer,
          $$CamerasTableAnnotationComposer,
          $$CamerasTableCreateCompanionBuilder,
          $$CamerasTableUpdateCompanionBuilder,
          (Camera, BaseReferences<_$AppDatabase, $CamerasTable, Camera>),
          Camera,
          PrefetchHooks Function()
        > {
  $$CamerasTableTableManager(_$AppDatabase db, $CamerasTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CamerasTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CamerasTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CamerasTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> brand = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<double> sensorWidthMm = const Value.absent(),
                Value<double> sensorHeightMm = const Value.absent(),
                Value<String?> recordingFormats = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => CamerasCompanion(
                id: id,
                brand: brand,
                model: model,
                sensorWidthMm: sensorWidthMm,
                sensorHeightMm: sensorHeightMm,
                recordingFormats: recordingFormats,
                notes: notes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String brand,
                required String model,
                required double sensorWidthMm,
                required double sensorHeightMm,
                Value<String?> recordingFormats = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => CamerasCompanion.insert(
                id: id,
                brand: brand,
                model: model,
                sensorWidthMm: sensorWidthMm,
                sensorHeightMm: sensorHeightMm,
                recordingFormats: recordingFormats,
                notes: notes,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CamerasTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CamerasTable,
      Camera,
      $$CamerasTableFilterComposer,
      $$CamerasTableOrderingComposer,
      $$CamerasTableAnnotationComposer,
      $$CamerasTableCreateCompanionBuilder,
      $$CamerasTableUpdateCompanionBuilder,
      (Camera, BaseReferences<_$AppDatabase, $CamerasTable, Camera>),
      Camera,
      PrefetchHooks Function()
    >;
typedef $$LensesTableCreateCompanionBuilder =
    LensesCompanion Function({
      Value<int> id,
      required String brand,
      required String model,
      required double focalLength,
      Value<double?> focalMin,
      Value<double?> focalMax,
      required double minTStop,
      required String formatCoverage,
      Value<String?> notes,
    });
typedef $$LensesTableUpdateCompanionBuilder =
    LensesCompanion Function({
      Value<int> id,
      Value<String> brand,
      Value<String> model,
      Value<double> focalLength,
      Value<double?> focalMin,
      Value<double?> focalMax,
      Value<double> minTStop,
      Value<String> formatCoverage,
      Value<String?> notes,
    });

final class $$LensesTableReferences
    extends BaseReferences<_$AppDatabase, $LensesTable, Lense> {
  $$LensesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$VisualBiblesTable, List<VisualBible>>
  _visualBiblesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.visualBibles,
    aliasName: $_aliasNameGenerator(
      db.lenses.id,
      db.visualBibles.primaryLensId,
    ),
  );

  $$VisualBiblesTableProcessedTableManager get visualBiblesRefs {
    final manager = $$VisualBiblesTableTableManager(
      $_db,
      $_db.visualBibles,
    ).filter((f) => f.primaryLensId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_visualBiblesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LensesTableFilterComposer
    extends Composer<_$AppDatabase, $LensesTable> {
  $$LensesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get brand => $composableBuilder(
    column: $table.brand,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get focalLength => $composableBuilder(
    column: $table.focalLength,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get focalMin => $composableBuilder(
    column: $table.focalMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get focalMax => $composableBuilder(
    column: $table.focalMax,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get minTStop => $composableBuilder(
    column: $table.minTStop,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get formatCoverage => $composableBuilder(
    column: $table.formatCoverage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> visualBiblesRefs(
    Expression<bool> Function($$VisualBiblesTableFilterComposer f) f,
  ) {
    final $$VisualBiblesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.visualBibles,
      getReferencedColumn: (t) => t.primaryLensId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VisualBiblesTableFilterComposer(
            $db: $db,
            $table: $db.visualBibles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LensesTableOrderingComposer
    extends Composer<_$AppDatabase, $LensesTable> {
  $$LensesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get brand => $composableBuilder(
    column: $table.brand,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get focalLength => $composableBuilder(
    column: $table.focalLength,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get focalMin => $composableBuilder(
    column: $table.focalMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get focalMax => $composableBuilder(
    column: $table.focalMax,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get minTStop => $composableBuilder(
    column: $table.minTStop,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get formatCoverage => $composableBuilder(
    column: $table.formatCoverage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LensesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LensesTable> {
  $$LensesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get brand =>
      $composableBuilder(column: $table.brand, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<double> get focalLength => $composableBuilder(
    column: $table.focalLength,
    builder: (column) => column,
  );

  GeneratedColumn<double> get focalMin =>
      $composableBuilder(column: $table.focalMin, builder: (column) => column);

  GeneratedColumn<double> get focalMax =>
      $composableBuilder(column: $table.focalMax, builder: (column) => column);

  GeneratedColumn<double> get minTStop =>
      $composableBuilder(column: $table.minTStop, builder: (column) => column);

  GeneratedColumn<String> get formatCoverage => $composableBuilder(
    column: $table.formatCoverage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  Expression<T> visualBiblesRefs<T extends Object>(
    Expression<T> Function($$VisualBiblesTableAnnotationComposer a) f,
  ) {
    final $$VisualBiblesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.visualBibles,
      getReferencedColumn: (t) => t.primaryLensId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VisualBiblesTableAnnotationComposer(
            $db: $db,
            $table: $db.visualBibles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LensesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LensesTable,
          Lense,
          $$LensesTableFilterComposer,
          $$LensesTableOrderingComposer,
          $$LensesTableAnnotationComposer,
          $$LensesTableCreateCompanionBuilder,
          $$LensesTableUpdateCompanionBuilder,
          (Lense, $$LensesTableReferences),
          Lense,
          PrefetchHooks Function({bool visualBiblesRefs})
        > {
  $$LensesTableTableManager(_$AppDatabase db, $LensesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LensesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LensesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LensesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> brand = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<double> focalLength = const Value.absent(),
                Value<double?> focalMin = const Value.absent(),
                Value<double?> focalMax = const Value.absent(),
                Value<double> minTStop = const Value.absent(),
                Value<String> formatCoverage = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => LensesCompanion(
                id: id,
                brand: brand,
                model: model,
                focalLength: focalLength,
                focalMin: focalMin,
                focalMax: focalMax,
                minTStop: minTStop,
                formatCoverage: formatCoverage,
                notes: notes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String brand,
                required String model,
                required double focalLength,
                Value<double?> focalMin = const Value.absent(),
                Value<double?> focalMax = const Value.absent(),
                required double minTStop,
                required String formatCoverage,
                Value<String?> notes = const Value.absent(),
              }) => LensesCompanion.insert(
                id: id,
                brand: brand,
                model: model,
                focalLength: focalLength,
                focalMin: focalMin,
                focalMax: focalMax,
                minTStop: minTStop,
                formatCoverage: formatCoverage,
                notes: notes,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$LensesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({visualBiblesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (visualBiblesRefs) db.visualBibles],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (visualBiblesRefs)
                    await $_getPrefetchedData<Lense, $LensesTable, VisualBible>(
                      currentTable: table,
                      referencedTable: $$LensesTableReferences
                          ._visualBiblesRefsTable(db),
                      managerFromTypedResult: (p0) => $$LensesTableReferences(
                        db,
                        table,
                        p0,
                      ).visualBiblesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.primaryLensId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$LensesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LensesTable,
      Lense,
      $$LensesTableFilterComposer,
      $$LensesTableOrderingComposer,
      $$LensesTableAnnotationComposer,
      $$LensesTableCreateCompanionBuilder,
      $$LensesTableUpdateCompanionBuilder,
      (Lense, $$LensesTableReferences),
      Lense,
      PrefetchHooks Function({bool visualBiblesRefs})
    >;
typedef $$LightsTableCreateCompanionBuilder =
    LightsCompanion Function({
      Value<int> id,
      required String brand,
      required String model,
      required String lightType,
      required int powerW,
      required int colorTempMin,
      required int colorTempMax,
      Value<bool> isLukaCompatible,
      Value<String?> lukaFixtureId,
      Value<String?> notes,
    });
typedef $$LightsTableUpdateCompanionBuilder =
    LightsCompanion Function({
      Value<int> id,
      Value<String> brand,
      Value<String> model,
      Value<String> lightType,
      Value<int> powerW,
      Value<int> colorTempMin,
      Value<int> colorTempMax,
      Value<bool> isLukaCompatible,
      Value<String?> lukaFixtureId,
      Value<String?> notes,
    });

class $$LightsTableFilterComposer
    extends Composer<_$AppDatabase, $LightsTable> {
  $$LightsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get brand => $composableBuilder(
    column: $table.brand,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lightType => $composableBuilder(
    column: $table.lightType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get powerW => $composableBuilder(
    column: $table.powerW,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorTempMin => $composableBuilder(
    column: $table.colorTempMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorTempMax => $composableBuilder(
    column: $table.colorTempMax,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isLukaCompatible => $composableBuilder(
    column: $table.isLukaCompatible,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lukaFixtureId => $composableBuilder(
    column: $table.lukaFixtureId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LightsTableOrderingComposer
    extends Composer<_$AppDatabase, $LightsTable> {
  $$LightsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get brand => $composableBuilder(
    column: $table.brand,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lightType => $composableBuilder(
    column: $table.lightType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get powerW => $composableBuilder(
    column: $table.powerW,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorTempMin => $composableBuilder(
    column: $table.colorTempMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorTempMax => $composableBuilder(
    column: $table.colorTempMax,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isLukaCompatible => $composableBuilder(
    column: $table.isLukaCompatible,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lukaFixtureId => $composableBuilder(
    column: $table.lukaFixtureId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LightsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LightsTable> {
  $$LightsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get brand =>
      $composableBuilder(column: $table.brand, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<String> get lightType =>
      $composableBuilder(column: $table.lightType, builder: (column) => column);

  GeneratedColumn<int> get powerW =>
      $composableBuilder(column: $table.powerW, builder: (column) => column);

  GeneratedColumn<int> get colorTempMin => $composableBuilder(
    column: $table.colorTempMin,
    builder: (column) => column,
  );

  GeneratedColumn<int> get colorTempMax => $composableBuilder(
    column: $table.colorTempMax,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isLukaCompatible => $composableBuilder(
    column: $table.isLukaCompatible,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lukaFixtureId => $composableBuilder(
    column: $table.lukaFixtureId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);
}

class $$LightsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LightsTable,
          Light,
          $$LightsTableFilterComposer,
          $$LightsTableOrderingComposer,
          $$LightsTableAnnotationComposer,
          $$LightsTableCreateCompanionBuilder,
          $$LightsTableUpdateCompanionBuilder,
          (Light, BaseReferences<_$AppDatabase, $LightsTable, Light>),
          Light,
          PrefetchHooks Function()
        > {
  $$LightsTableTableManager(_$AppDatabase db, $LightsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LightsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LightsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LightsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> brand = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<String> lightType = const Value.absent(),
                Value<int> powerW = const Value.absent(),
                Value<int> colorTempMin = const Value.absent(),
                Value<int> colorTempMax = const Value.absent(),
                Value<bool> isLukaCompatible = const Value.absent(),
                Value<String?> lukaFixtureId = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => LightsCompanion(
                id: id,
                brand: brand,
                model: model,
                lightType: lightType,
                powerW: powerW,
                colorTempMin: colorTempMin,
                colorTempMax: colorTempMax,
                isLukaCompatible: isLukaCompatible,
                lukaFixtureId: lukaFixtureId,
                notes: notes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String brand,
                required String model,
                required String lightType,
                required int powerW,
                required int colorTempMin,
                required int colorTempMax,
                Value<bool> isLukaCompatible = const Value.absent(),
                Value<String?> lukaFixtureId = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => LightsCompanion.insert(
                id: id,
                brand: brand,
                model: model,
                lightType: lightType,
                powerW: powerW,
                colorTempMin: colorTempMin,
                colorTempMax: colorTempMax,
                isLukaCompatible: isLukaCompatible,
                lukaFixtureId: lukaFixtureId,
                notes: notes,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LightsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LightsTable,
      Light,
      $$LightsTableFilterComposer,
      $$LightsTableOrderingComposer,
      $$LightsTableAnnotationComposer,
      $$LightsTableCreateCompanionBuilder,
      $$LightsTableUpdateCompanionBuilder,
      (Light, BaseReferences<_$AppDatabase, $LightsTable, Light>),
      Light,
      PrefetchHooks Function()
    >;
typedef $$ProjectEquipmentTableCreateCompanionBuilder =
    ProjectEquipmentCompanion Function({
      Value<int> id,
      required int projectId,
      required String equipmentType,
      required int equipmentId,
      Value<String> source,
      Value<String> status,
      Value<String?> notes,
    });
typedef $$ProjectEquipmentTableUpdateCompanionBuilder =
    ProjectEquipmentCompanion Function({
      Value<int> id,
      Value<int> projectId,
      Value<String> equipmentType,
      Value<int> equipmentId,
      Value<String> source,
      Value<String> status,
      Value<String?> notes,
    });

final class $$ProjectEquipmentTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ProjectEquipmentTable,
          ProjectEquipmentData
        > {
  $$ProjectEquipmentTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias(
        $_aliasNameGenerator(db.projectEquipment.projectId, db.projects.id),
      );

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<int>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ProjectEquipmentTableFilterComposer
    extends Composer<_$AppDatabase, $ProjectEquipmentTable> {
  $$ProjectEquipmentTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get equipmentType => $composableBuilder(
    column: $table.equipmentType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get equipmentId => $composableBuilder(
    column: $table.equipmentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProjectEquipmentTableOrderingComposer
    extends Composer<_$AppDatabase, $ProjectEquipmentTable> {
  $$ProjectEquipmentTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get equipmentType => $composableBuilder(
    column: $table.equipmentType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get equipmentId => $composableBuilder(
    column: $table.equipmentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProjectEquipmentTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProjectEquipmentTable> {
  $$ProjectEquipmentTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get equipmentType => $composableBuilder(
    column: $table.equipmentType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get equipmentId => $composableBuilder(
    column: $table.equipmentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProjectEquipmentTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProjectEquipmentTable,
          ProjectEquipmentData,
          $$ProjectEquipmentTableFilterComposer,
          $$ProjectEquipmentTableOrderingComposer,
          $$ProjectEquipmentTableAnnotationComposer,
          $$ProjectEquipmentTableCreateCompanionBuilder,
          $$ProjectEquipmentTableUpdateCompanionBuilder,
          (ProjectEquipmentData, $$ProjectEquipmentTableReferences),
          ProjectEquipmentData,
          PrefetchHooks Function({bool projectId})
        > {
  $$ProjectEquipmentTableTableManager(
    _$AppDatabase db,
    $ProjectEquipmentTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectEquipmentTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectEquipmentTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectEquipmentTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> projectId = const Value.absent(),
                Value<String> equipmentType = const Value.absent(),
                Value<int> equipmentId = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => ProjectEquipmentCompanion(
                id: id,
                projectId: projectId,
                equipmentType: equipmentType,
                equipmentId: equipmentId,
                source: source,
                status: status,
                notes: notes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int projectId,
                required String equipmentType,
                required int equipmentId,
                Value<String> source = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => ProjectEquipmentCompanion.insert(
                id: id,
                projectId: projectId,
                equipmentType: equipmentType,
                equipmentId: equipmentId,
                source: source,
                status: status,
                notes: notes,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProjectEquipmentTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({projectId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (projectId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.projectId,
                                referencedTable:
                                    $$ProjectEquipmentTableReferences
                                        ._projectIdTable(db),
                                referencedColumn:
                                    $$ProjectEquipmentTableReferences
                                        ._projectIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ProjectEquipmentTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProjectEquipmentTable,
      ProjectEquipmentData,
      $$ProjectEquipmentTableFilterComposer,
      $$ProjectEquipmentTableOrderingComposer,
      $$ProjectEquipmentTableAnnotationComposer,
      $$ProjectEquipmentTableCreateCompanionBuilder,
      $$ProjectEquipmentTableUpdateCompanionBuilder,
      (ProjectEquipmentData, $$ProjectEquipmentTableReferences),
      ProjectEquipmentData,
      PrefetchHooks Function({bool projectId})
    >;
typedef $$LookBiblesTableCreateCompanionBuilder =
    LookBiblesCompanion Function({
      Value<int> id,
      required int projectId,
      Value<String?> visualConcept,
      Value<String?> colorPalette,
      Value<String?> lutName,
      Value<String?> filmReferences,
      Value<String?> lightingPhilosophy,
      Value<String?> contrastStyle,
      Value<String?> actOneNotes,
      Value<String?> actTwoNotes,
      Value<String?> actThreeNotes,
      Value<String?> moodboardImages,
      Value<DateTime> updatedAt,
    });
typedef $$LookBiblesTableUpdateCompanionBuilder =
    LookBiblesCompanion Function({
      Value<int> id,
      Value<int> projectId,
      Value<String?> visualConcept,
      Value<String?> colorPalette,
      Value<String?> lutName,
      Value<String?> filmReferences,
      Value<String?> lightingPhilosophy,
      Value<String?> contrastStyle,
      Value<String?> actOneNotes,
      Value<String?> actTwoNotes,
      Value<String?> actThreeNotes,
      Value<String?> moodboardImages,
      Value<DateTime> updatedAt,
    });

final class $$LookBiblesTableReferences
    extends BaseReferences<_$AppDatabase, $LookBiblesTable, LookBible> {
  $$LookBiblesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias(
        $_aliasNameGenerator(db.lookBibles.projectId, db.projects.id),
      );

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<int>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LookBiblesTableFilterComposer
    extends Composer<_$AppDatabase, $LookBiblesTable> {
  $$LookBiblesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get visualConcept => $composableBuilder(
    column: $table.visualConcept,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorPalette => $composableBuilder(
    column: $table.colorPalette,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lutName => $composableBuilder(
    column: $table.lutName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filmReferences => $composableBuilder(
    column: $table.filmReferences,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lightingPhilosophy => $composableBuilder(
    column: $table.lightingPhilosophy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contrastStyle => $composableBuilder(
    column: $table.contrastStyle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actOneNotes => $composableBuilder(
    column: $table.actOneNotes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actTwoNotes => $composableBuilder(
    column: $table.actTwoNotes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actThreeNotes => $composableBuilder(
    column: $table.actThreeNotes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get moodboardImages => $composableBuilder(
    column: $table.moodboardImages,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LookBiblesTableOrderingComposer
    extends Composer<_$AppDatabase, $LookBiblesTable> {
  $$LookBiblesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get visualConcept => $composableBuilder(
    column: $table.visualConcept,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorPalette => $composableBuilder(
    column: $table.colorPalette,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lutName => $composableBuilder(
    column: $table.lutName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filmReferences => $composableBuilder(
    column: $table.filmReferences,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lightingPhilosophy => $composableBuilder(
    column: $table.lightingPhilosophy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contrastStyle => $composableBuilder(
    column: $table.contrastStyle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actOneNotes => $composableBuilder(
    column: $table.actOneNotes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actTwoNotes => $composableBuilder(
    column: $table.actTwoNotes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actThreeNotes => $composableBuilder(
    column: $table.actThreeNotes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get moodboardImages => $composableBuilder(
    column: $table.moodboardImages,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LookBiblesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LookBiblesTable> {
  $$LookBiblesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get visualConcept => $composableBuilder(
    column: $table.visualConcept,
    builder: (column) => column,
  );

  GeneratedColumn<String> get colorPalette => $composableBuilder(
    column: $table.colorPalette,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lutName =>
      $composableBuilder(column: $table.lutName, builder: (column) => column);

  GeneratedColumn<String> get filmReferences => $composableBuilder(
    column: $table.filmReferences,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lightingPhilosophy => $composableBuilder(
    column: $table.lightingPhilosophy,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contrastStyle => $composableBuilder(
    column: $table.contrastStyle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get actOneNotes => $composableBuilder(
    column: $table.actOneNotes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get actTwoNotes => $composableBuilder(
    column: $table.actTwoNotes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get actThreeNotes => $composableBuilder(
    column: $table.actThreeNotes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get moodboardImages => $composableBuilder(
    column: $table.moodboardImages,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LookBiblesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LookBiblesTable,
          LookBible,
          $$LookBiblesTableFilterComposer,
          $$LookBiblesTableOrderingComposer,
          $$LookBiblesTableAnnotationComposer,
          $$LookBiblesTableCreateCompanionBuilder,
          $$LookBiblesTableUpdateCompanionBuilder,
          (LookBible, $$LookBiblesTableReferences),
          LookBible,
          PrefetchHooks Function({bool projectId})
        > {
  $$LookBiblesTableTableManager(_$AppDatabase db, $LookBiblesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LookBiblesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LookBiblesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LookBiblesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> projectId = const Value.absent(),
                Value<String?> visualConcept = const Value.absent(),
                Value<String?> colorPalette = const Value.absent(),
                Value<String?> lutName = const Value.absent(),
                Value<String?> filmReferences = const Value.absent(),
                Value<String?> lightingPhilosophy = const Value.absent(),
                Value<String?> contrastStyle = const Value.absent(),
                Value<String?> actOneNotes = const Value.absent(),
                Value<String?> actTwoNotes = const Value.absent(),
                Value<String?> actThreeNotes = const Value.absent(),
                Value<String?> moodboardImages = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => LookBiblesCompanion(
                id: id,
                projectId: projectId,
                visualConcept: visualConcept,
                colorPalette: colorPalette,
                lutName: lutName,
                filmReferences: filmReferences,
                lightingPhilosophy: lightingPhilosophy,
                contrastStyle: contrastStyle,
                actOneNotes: actOneNotes,
                actTwoNotes: actTwoNotes,
                actThreeNotes: actThreeNotes,
                moodboardImages: moodboardImages,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int projectId,
                Value<String?> visualConcept = const Value.absent(),
                Value<String?> colorPalette = const Value.absent(),
                Value<String?> lutName = const Value.absent(),
                Value<String?> filmReferences = const Value.absent(),
                Value<String?> lightingPhilosophy = const Value.absent(),
                Value<String?> contrastStyle = const Value.absent(),
                Value<String?> actOneNotes = const Value.absent(),
                Value<String?> actTwoNotes = const Value.absent(),
                Value<String?> actThreeNotes = const Value.absent(),
                Value<String?> moodboardImages = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => LookBiblesCompanion.insert(
                id: id,
                projectId: projectId,
                visualConcept: visualConcept,
                colorPalette: colorPalette,
                lutName: lutName,
                filmReferences: filmReferences,
                lightingPhilosophy: lightingPhilosophy,
                contrastStyle: contrastStyle,
                actOneNotes: actOneNotes,
                actTwoNotes: actTwoNotes,
                actThreeNotes: actThreeNotes,
                moodboardImages: moodboardImages,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LookBiblesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({projectId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (projectId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.projectId,
                                referencedTable: $$LookBiblesTableReferences
                                    ._projectIdTable(db),
                                referencedColumn: $$LookBiblesTableReferences
                                    ._projectIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LookBiblesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LookBiblesTable,
      LookBible,
      $$LookBiblesTableFilterComposer,
      $$LookBiblesTableOrderingComposer,
      $$LookBiblesTableAnnotationComposer,
      $$LookBiblesTableCreateCompanionBuilder,
      $$LookBiblesTableUpdateCompanionBuilder,
      (LookBible, $$LookBiblesTableReferences),
      LookBible,
      PrefetchHooks Function({bool projectId})
    >;
typedef $$ProjectAnnotatedPdfsTableCreateCompanionBuilder =
    ProjectAnnotatedPdfsCompanion Function({
      Value<int> id,
      required int projectId,
      required String moduleType,
      required String pdfPath,
      Value<DateTime> importedAt,
    });
typedef $$ProjectAnnotatedPdfsTableUpdateCompanionBuilder =
    ProjectAnnotatedPdfsCompanion Function({
      Value<int> id,
      Value<int> projectId,
      Value<String> moduleType,
      Value<String> pdfPath,
      Value<DateTime> importedAt,
    });

final class $$ProjectAnnotatedPdfsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ProjectAnnotatedPdfsTable,
          ProjectAnnotatedPdf
        > {
  $$ProjectAnnotatedPdfsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias(
        $_aliasNameGenerator(db.projectAnnotatedPdfs.projectId, db.projects.id),
      );

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<int>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ProjectAnnotatedPdfsTableFilterComposer
    extends Composer<_$AppDatabase, $ProjectAnnotatedPdfsTable> {
  $$ProjectAnnotatedPdfsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get moduleType => $composableBuilder(
    column: $table.moduleType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pdfPath => $composableBuilder(
    column: $table.pdfPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProjectAnnotatedPdfsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProjectAnnotatedPdfsTable> {
  $$ProjectAnnotatedPdfsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get moduleType => $composableBuilder(
    column: $table.moduleType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pdfPath => $composableBuilder(
    column: $table.pdfPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProjectAnnotatedPdfsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProjectAnnotatedPdfsTable> {
  $$ProjectAnnotatedPdfsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get moduleType => $composableBuilder(
    column: $table.moduleType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pdfPath =>
      $composableBuilder(column: $table.pdfPath, builder: (column) => column);

  GeneratedColumn<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => column,
  );

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProjectAnnotatedPdfsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProjectAnnotatedPdfsTable,
          ProjectAnnotatedPdf,
          $$ProjectAnnotatedPdfsTableFilterComposer,
          $$ProjectAnnotatedPdfsTableOrderingComposer,
          $$ProjectAnnotatedPdfsTableAnnotationComposer,
          $$ProjectAnnotatedPdfsTableCreateCompanionBuilder,
          $$ProjectAnnotatedPdfsTableUpdateCompanionBuilder,
          (ProjectAnnotatedPdf, $$ProjectAnnotatedPdfsTableReferences),
          ProjectAnnotatedPdf,
          PrefetchHooks Function({bool projectId})
        > {
  $$ProjectAnnotatedPdfsTableTableManager(
    _$AppDatabase db,
    $ProjectAnnotatedPdfsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectAnnotatedPdfsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectAnnotatedPdfsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ProjectAnnotatedPdfsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> projectId = const Value.absent(),
                Value<String> moduleType = const Value.absent(),
                Value<String> pdfPath = const Value.absent(),
                Value<DateTime> importedAt = const Value.absent(),
              }) => ProjectAnnotatedPdfsCompanion(
                id: id,
                projectId: projectId,
                moduleType: moduleType,
                pdfPath: pdfPath,
                importedAt: importedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int projectId,
                required String moduleType,
                required String pdfPath,
                Value<DateTime> importedAt = const Value.absent(),
              }) => ProjectAnnotatedPdfsCompanion.insert(
                id: id,
                projectId: projectId,
                moduleType: moduleType,
                pdfPath: pdfPath,
                importedAt: importedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProjectAnnotatedPdfsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({projectId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (projectId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.projectId,
                                referencedTable:
                                    $$ProjectAnnotatedPdfsTableReferences
                                        ._projectIdTable(db),
                                referencedColumn:
                                    $$ProjectAnnotatedPdfsTableReferences
                                        ._projectIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ProjectAnnotatedPdfsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProjectAnnotatedPdfsTable,
      ProjectAnnotatedPdf,
      $$ProjectAnnotatedPdfsTableFilterComposer,
      $$ProjectAnnotatedPdfsTableOrderingComposer,
      $$ProjectAnnotatedPdfsTableAnnotationComposer,
      $$ProjectAnnotatedPdfsTableCreateCompanionBuilder,
      $$ProjectAnnotatedPdfsTableUpdateCompanionBuilder,
      (ProjectAnnotatedPdf, $$ProjectAnnotatedPdfsTableReferences),
      ProjectAnnotatedPdf,
      PrefetchHooks Function({bool projectId})
    >;
typedef $$VisualBiblesTableCreateCompanionBuilder =
    VisualBiblesCompanion Function({
      Value<int> id,
      required int projectId,
      Value<String?> visualConcept,
      Value<String?> narrativeReferences,
      Value<String?> lightingPhilosophy,
      Value<String?> lightQuality,
      Value<String?> contrastStyle,
      Value<String?> keyFillRatioDay,
      Value<String?> keyFillRatioNight,
      Value<String?> lightSource,
      Value<String?> cameraPhilosophy,
      Value<String?> movementStyle,
      Value<String?> preferredMovements,
      Value<String?> lensPhilosophy,
      Value<String?> opticType,
      Value<String?> primaryFocalLengths,
      Value<int?> primaryLensId,
      Value<String?> aspectRatio,
      Value<String?> aspectRatioJustification,
      Value<String?> imageTexture,
      Value<String?> grainLevel,
      Value<String?> highlightBehavior,
      Value<String?> shadowBehavior,
      Value<String?> workingLutName,
      Value<String?> creativeLutName,
      Value<String?> creativeLutDescription,
      Value<DateTime> updatedAt,
    });
typedef $$VisualBiblesTableUpdateCompanionBuilder =
    VisualBiblesCompanion Function({
      Value<int> id,
      Value<int> projectId,
      Value<String?> visualConcept,
      Value<String?> narrativeReferences,
      Value<String?> lightingPhilosophy,
      Value<String?> lightQuality,
      Value<String?> contrastStyle,
      Value<String?> keyFillRatioDay,
      Value<String?> keyFillRatioNight,
      Value<String?> lightSource,
      Value<String?> cameraPhilosophy,
      Value<String?> movementStyle,
      Value<String?> preferredMovements,
      Value<String?> lensPhilosophy,
      Value<String?> opticType,
      Value<String?> primaryFocalLengths,
      Value<int?> primaryLensId,
      Value<String?> aspectRatio,
      Value<String?> aspectRatioJustification,
      Value<String?> imageTexture,
      Value<String?> grainLevel,
      Value<String?> highlightBehavior,
      Value<String?> shadowBehavior,
      Value<String?> workingLutName,
      Value<String?> creativeLutName,
      Value<String?> creativeLutDescription,
      Value<DateTime> updatedAt,
    });

final class $$VisualBiblesTableReferences
    extends BaseReferences<_$AppDatabase, $VisualBiblesTable, VisualBible> {
  $$VisualBiblesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias(
        $_aliasNameGenerator(db.visualBibles.projectId, db.projects.id),
      );

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<int>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $LensesTable _primaryLensIdTable(_$AppDatabase db) =>
      db.lenses.createAlias(
        $_aliasNameGenerator(db.visualBibles.primaryLensId, db.lenses.id),
      );

  $$LensesTableProcessedTableManager? get primaryLensId {
    final $_column = $_itemColumn<int>('primary_lens_id');
    if ($_column == null) return null;
    final manager = $$LensesTableTableManager(
      $_db,
      $_db.lenses,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_primaryLensIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $VisualBibleColorBlocksTable,
    List<VisualBibleColorBlock>
  >
  _visualBibleColorBlocksRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.visualBibleColorBlocks,
        aliasName: $_aliasNameGenerator(
          db.visualBibles.id,
          db.visualBibleColorBlocks.bibleId,
        ),
      );

  $$VisualBibleColorBlocksTableProcessedTableManager
  get visualBibleColorBlocksRefs {
    final manager = $$VisualBibleColorBlocksTableTableManager(
      $_db,
      $_db.visualBibleColorBlocks,
    ).filter((f) => f.bibleId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _visualBibleColorBlocksRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $VisualBibleLocationRefsTable,
    List<VisualBibleLocationRef>
  >
  _visualBibleLocationRefsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.visualBibleLocationRefs,
        aliasName: $_aliasNameGenerator(
          db.visualBibles.id,
          db.visualBibleLocationRefs.bibleId,
        ),
      );

  $$VisualBibleLocationRefsTableProcessedTableManager
  get visualBibleLocationRefsRefs {
    final manager = $$VisualBibleLocationRefsTableTableManager(
      $_db,
      $_db.visualBibleLocationRefs,
    ).filter((f) => f.bibleId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _visualBibleLocationRefsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MoodboardImagesTable, List<MoodboardImage>>
  _moodboardImagesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.moodboardImages,
    aliasName: $_aliasNameGenerator(
      db.visualBibles.id,
      db.moodboardImages.bibleId,
    ),
  );

  $$MoodboardImagesTableProcessedTableManager get moodboardImagesRefs {
    final manager = $$MoodboardImagesTableTableManager(
      $_db,
      $_db.moodboardImages,
    ).filter((f) => f.bibleId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _moodboardImagesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$VisualBiblesTableFilterComposer
    extends Composer<_$AppDatabase, $VisualBiblesTable> {
  $$VisualBiblesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get visualConcept => $composableBuilder(
    column: $table.visualConcept,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get narrativeReferences => $composableBuilder(
    column: $table.narrativeReferences,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lightingPhilosophy => $composableBuilder(
    column: $table.lightingPhilosophy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lightQuality => $composableBuilder(
    column: $table.lightQuality,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contrastStyle => $composableBuilder(
    column: $table.contrastStyle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get keyFillRatioDay => $composableBuilder(
    column: $table.keyFillRatioDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get keyFillRatioNight => $composableBuilder(
    column: $table.keyFillRatioNight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lightSource => $composableBuilder(
    column: $table.lightSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cameraPhilosophy => $composableBuilder(
    column: $table.cameraPhilosophy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get movementStyle => $composableBuilder(
    column: $table.movementStyle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preferredMovements => $composableBuilder(
    column: $table.preferredMovements,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lensPhilosophy => $composableBuilder(
    column: $table.lensPhilosophy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get opticType => $composableBuilder(
    column: $table.opticType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get primaryFocalLengths => $composableBuilder(
    column: $table.primaryFocalLengths,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aspectRatio => $composableBuilder(
    column: $table.aspectRatio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aspectRatioJustification => $composableBuilder(
    column: $table.aspectRatioJustification,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageTexture => $composableBuilder(
    column: $table.imageTexture,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get grainLevel => $composableBuilder(
    column: $table.grainLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get highlightBehavior => $composableBuilder(
    column: $table.highlightBehavior,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shadowBehavior => $composableBuilder(
    column: $table.shadowBehavior,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get workingLutName => $composableBuilder(
    column: $table.workingLutName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get creativeLutName => $composableBuilder(
    column: $table.creativeLutName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get creativeLutDescription => $composableBuilder(
    column: $table.creativeLutDescription,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LensesTableFilterComposer get primaryLensId {
    final $$LensesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.primaryLensId,
      referencedTable: $db.lenses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LensesTableFilterComposer(
            $db: $db,
            $table: $db.lenses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> visualBibleColorBlocksRefs(
    Expression<bool> Function($$VisualBibleColorBlocksTableFilterComposer f) f,
  ) {
    final $$VisualBibleColorBlocksTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.visualBibleColorBlocks,
          getReferencedColumn: (t) => t.bibleId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$VisualBibleColorBlocksTableFilterComposer(
                $db: $db,
                $table: $db.visualBibleColorBlocks,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> visualBibleLocationRefsRefs(
    Expression<bool> Function($$VisualBibleLocationRefsTableFilterComposer f) f,
  ) {
    final $$VisualBibleLocationRefsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.visualBibleLocationRefs,
          getReferencedColumn: (t) => t.bibleId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$VisualBibleLocationRefsTableFilterComposer(
                $db: $db,
                $table: $db.visualBibleLocationRefs,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> moodboardImagesRefs(
    Expression<bool> Function($$MoodboardImagesTableFilterComposer f) f,
  ) {
    final $$MoodboardImagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.moodboardImages,
      getReferencedColumn: (t) => t.bibleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MoodboardImagesTableFilterComposer(
            $db: $db,
            $table: $db.moodboardImages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$VisualBiblesTableOrderingComposer
    extends Composer<_$AppDatabase, $VisualBiblesTable> {
  $$VisualBiblesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get visualConcept => $composableBuilder(
    column: $table.visualConcept,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get narrativeReferences => $composableBuilder(
    column: $table.narrativeReferences,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lightingPhilosophy => $composableBuilder(
    column: $table.lightingPhilosophy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lightQuality => $composableBuilder(
    column: $table.lightQuality,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contrastStyle => $composableBuilder(
    column: $table.contrastStyle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get keyFillRatioDay => $composableBuilder(
    column: $table.keyFillRatioDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get keyFillRatioNight => $composableBuilder(
    column: $table.keyFillRatioNight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lightSource => $composableBuilder(
    column: $table.lightSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cameraPhilosophy => $composableBuilder(
    column: $table.cameraPhilosophy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get movementStyle => $composableBuilder(
    column: $table.movementStyle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preferredMovements => $composableBuilder(
    column: $table.preferredMovements,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lensPhilosophy => $composableBuilder(
    column: $table.lensPhilosophy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get opticType => $composableBuilder(
    column: $table.opticType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get primaryFocalLengths => $composableBuilder(
    column: $table.primaryFocalLengths,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aspectRatio => $composableBuilder(
    column: $table.aspectRatio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aspectRatioJustification => $composableBuilder(
    column: $table.aspectRatioJustification,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageTexture => $composableBuilder(
    column: $table.imageTexture,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get grainLevel => $composableBuilder(
    column: $table.grainLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get highlightBehavior => $composableBuilder(
    column: $table.highlightBehavior,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shadowBehavior => $composableBuilder(
    column: $table.shadowBehavior,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workingLutName => $composableBuilder(
    column: $table.workingLutName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get creativeLutName => $composableBuilder(
    column: $table.creativeLutName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get creativeLutDescription => $composableBuilder(
    column: $table.creativeLutDescription,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LensesTableOrderingComposer get primaryLensId {
    final $$LensesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.primaryLensId,
      referencedTable: $db.lenses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LensesTableOrderingComposer(
            $db: $db,
            $table: $db.lenses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VisualBiblesTableAnnotationComposer
    extends Composer<_$AppDatabase, $VisualBiblesTable> {
  $$VisualBiblesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get visualConcept => $composableBuilder(
    column: $table.visualConcept,
    builder: (column) => column,
  );

  GeneratedColumn<String> get narrativeReferences => $composableBuilder(
    column: $table.narrativeReferences,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lightingPhilosophy => $composableBuilder(
    column: $table.lightingPhilosophy,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lightQuality => $composableBuilder(
    column: $table.lightQuality,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contrastStyle => $composableBuilder(
    column: $table.contrastStyle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get keyFillRatioDay => $composableBuilder(
    column: $table.keyFillRatioDay,
    builder: (column) => column,
  );

  GeneratedColumn<String> get keyFillRatioNight => $composableBuilder(
    column: $table.keyFillRatioNight,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lightSource => $composableBuilder(
    column: $table.lightSource,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cameraPhilosophy => $composableBuilder(
    column: $table.cameraPhilosophy,
    builder: (column) => column,
  );

  GeneratedColumn<String> get movementStyle => $composableBuilder(
    column: $table.movementStyle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get preferredMovements => $composableBuilder(
    column: $table.preferredMovements,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lensPhilosophy => $composableBuilder(
    column: $table.lensPhilosophy,
    builder: (column) => column,
  );

  GeneratedColumn<String> get opticType =>
      $composableBuilder(column: $table.opticType, builder: (column) => column);

  GeneratedColumn<String> get primaryFocalLengths => $composableBuilder(
    column: $table.primaryFocalLengths,
    builder: (column) => column,
  );

  GeneratedColumn<String> get aspectRatio => $composableBuilder(
    column: $table.aspectRatio,
    builder: (column) => column,
  );

  GeneratedColumn<String> get aspectRatioJustification => $composableBuilder(
    column: $table.aspectRatioJustification,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageTexture => $composableBuilder(
    column: $table.imageTexture,
    builder: (column) => column,
  );

  GeneratedColumn<String> get grainLevel => $composableBuilder(
    column: $table.grainLevel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get highlightBehavior => $composableBuilder(
    column: $table.highlightBehavior,
    builder: (column) => column,
  );

  GeneratedColumn<String> get shadowBehavior => $composableBuilder(
    column: $table.shadowBehavior,
    builder: (column) => column,
  );

  GeneratedColumn<String> get workingLutName => $composableBuilder(
    column: $table.workingLutName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get creativeLutName => $composableBuilder(
    column: $table.creativeLutName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get creativeLutDescription => $composableBuilder(
    column: $table.creativeLutDescription,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LensesTableAnnotationComposer get primaryLensId {
    final $$LensesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.primaryLensId,
      referencedTable: $db.lenses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LensesTableAnnotationComposer(
            $db: $db,
            $table: $db.lenses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> visualBibleColorBlocksRefs<T extends Object>(
    Expression<T> Function($$VisualBibleColorBlocksTableAnnotationComposer a) f,
  ) {
    final $$VisualBibleColorBlocksTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.visualBibleColorBlocks,
          getReferencedColumn: (t) => t.bibleId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$VisualBibleColorBlocksTableAnnotationComposer(
                $db: $db,
                $table: $db.visualBibleColorBlocks,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> visualBibleLocationRefsRefs<T extends Object>(
    Expression<T> Function($$VisualBibleLocationRefsTableAnnotationComposer a)
    f,
  ) {
    final $$VisualBibleLocationRefsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.visualBibleLocationRefs,
          getReferencedColumn: (t) => t.bibleId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$VisualBibleLocationRefsTableAnnotationComposer(
                $db: $db,
                $table: $db.visualBibleLocationRefs,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> moodboardImagesRefs<T extends Object>(
    Expression<T> Function($$MoodboardImagesTableAnnotationComposer a) f,
  ) {
    final $$MoodboardImagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.moodboardImages,
      getReferencedColumn: (t) => t.bibleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MoodboardImagesTableAnnotationComposer(
            $db: $db,
            $table: $db.moodboardImages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$VisualBiblesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VisualBiblesTable,
          VisualBible,
          $$VisualBiblesTableFilterComposer,
          $$VisualBiblesTableOrderingComposer,
          $$VisualBiblesTableAnnotationComposer,
          $$VisualBiblesTableCreateCompanionBuilder,
          $$VisualBiblesTableUpdateCompanionBuilder,
          (VisualBible, $$VisualBiblesTableReferences),
          VisualBible,
          PrefetchHooks Function({
            bool projectId,
            bool primaryLensId,
            bool visualBibleColorBlocksRefs,
            bool visualBibleLocationRefsRefs,
            bool moodboardImagesRefs,
          })
        > {
  $$VisualBiblesTableTableManager(_$AppDatabase db, $VisualBiblesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VisualBiblesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VisualBiblesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VisualBiblesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> projectId = const Value.absent(),
                Value<String?> visualConcept = const Value.absent(),
                Value<String?> narrativeReferences = const Value.absent(),
                Value<String?> lightingPhilosophy = const Value.absent(),
                Value<String?> lightQuality = const Value.absent(),
                Value<String?> contrastStyle = const Value.absent(),
                Value<String?> keyFillRatioDay = const Value.absent(),
                Value<String?> keyFillRatioNight = const Value.absent(),
                Value<String?> lightSource = const Value.absent(),
                Value<String?> cameraPhilosophy = const Value.absent(),
                Value<String?> movementStyle = const Value.absent(),
                Value<String?> preferredMovements = const Value.absent(),
                Value<String?> lensPhilosophy = const Value.absent(),
                Value<String?> opticType = const Value.absent(),
                Value<String?> primaryFocalLengths = const Value.absent(),
                Value<int?> primaryLensId = const Value.absent(),
                Value<String?> aspectRatio = const Value.absent(),
                Value<String?> aspectRatioJustification = const Value.absent(),
                Value<String?> imageTexture = const Value.absent(),
                Value<String?> grainLevel = const Value.absent(),
                Value<String?> highlightBehavior = const Value.absent(),
                Value<String?> shadowBehavior = const Value.absent(),
                Value<String?> workingLutName = const Value.absent(),
                Value<String?> creativeLutName = const Value.absent(),
                Value<String?> creativeLutDescription = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => VisualBiblesCompanion(
                id: id,
                projectId: projectId,
                visualConcept: visualConcept,
                narrativeReferences: narrativeReferences,
                lightingPhilosophy: lightingPhilosophy,
                lightQuality: lightQuality,
                contrastStyle: contrastStyle,
                keyFillRatioDay: keyFillRatioDay,
                keyFillRatioNight: keyFillRatioNight,
                lightSource: lightSource,
                cameraPhilosophy: cameraPhilosophy,
                movementStyle: movementStyle,
                preferredMovements: preferredMovements,
                lensPhilosophy: lensPhilosophy,
                opticType: opticType,
                primaryFocalLengths: primaryFocalLengths,
                primaryLensId: primaryLensId,
                aspectRatio: aspectRatio,
                aspectRatioJustification: aspectRatioJustification,
                imageTexture: imageTexture,
                grainLevel: grainLevel,
                highlightBehavior: highlightBehavior,
                shadowBehavior: shadowBehavior,
                workingLutName: workingLutName,
                creativeLutName: creativeLutName,
                creativeLutDescription: creativeLutDescription,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int projectId,
                Value<String?> visualConcept = const Value.absent(),
                Value<String?> narrativeReferences = const Value.absent(),
                Value<String?> lightingPhilosophy = const Value.absent(),
                Value<String?> lightQuality = const Value.absent(),
                Value<String?> contrastStyle = const Value.absent(),
                Value<String?> keyFillRatioDay = const Value.absent(),
                Value<String?> keyFillRatioNight = const Value.absent(),
                Value<String?> lightSource = const Value.absent(),
                Value<String?> cameraPhilosophy = const Value.absent(),
                Value<String?> movementStyle = const Value.absent(),
                Value<String?> preferredMovements = const Value.absent(),
                Value<String?> lensPhilosophy = const Value.absent(),
                Value<String?> opticType = const Value.absent(),
                Value<String?> primaryFocalLengths = const Value.absent(),
                Value<int?> primaryLensId = const Value.absent(),
                Value<String?> aspectRatio = const Value.absent(),
                Value<String?> aspectRatioJustification = const Value.absent(),
                Value<String?> imageTexture = const Value.absent(),
                Value<String?> grainLevel = const Value.absent(),
                Value<String?> highlightBehavior = const Value.absent(),
                Value<String?> shadowBehavior = const Value.absent(),
                Value<String?> workingLutName = const Value.absent(),
                Value<String?> creativeLutName = const Value.absent(),
                Value<String?> creativeLutDescription = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => VisualBiblesCompanion.insert(
                id: id,
                projectId: projectId,
                visualConcept: visualConcept,
                narrativeReferences: narrativeReferences,
                lightingPhilosophy: lightingPhilosophy,
                lightQuality: lightQuality,
                contrastStyle: contrastStyle,
                keyFillRatioDay: keyFillRatioDay,
                keyFillRatioNight: keyFillRatioNight,
                lightSource: lightSource,
                cameraPhilosophy: cameraPhilosophy,
                movementStyle: movementStyle,
                preferredMovements: preferredMovements,
                lensPhilosophy: lensPhilosophy,
                opticType: opticType,
                primaryFocalLengths: primaryFocalLengths,
                primaryLensId: primaryLensId,
                aspectRatio: aspectRatio,
                aspectRatioJustification: aspectRatioJustification,
                imageTexture: imageTexture,
                grainLevel: grainLevel,
                highlightBehavior: highlightBehavior,
                shadowBehavior: shadowBehavior,
                workingLutName: workingLutName,
                creativeLutName: creativeLutName,
                creativeLutDescription: creativeLutDescription,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$VisualBiblesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                projectId = false,
                primaryLensId = false,
                visualBibleColorBlocksRefs = false,
                visualBibleLocationRefsRefs = false,
                moodboardImagesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (visualBibleColorBlocksRefs) db.visualBibleColorBlocks,
                    if (visualBibleLocationRefsRefs) db.visualBibleLocationRefs,
                    if (moodboardImagesRefs) db.moodboardImages,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (projectId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.projectId,
                                    referencedTable:
                                        $$VisualBiblesTableReferences
                                            ._projectIdTable(db),
                                    referencedColumn:
                                        $$VisualBiblesTableReferences
                                            ._projectIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (primaryLensId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.primaryLensId,
                                    referencedTable:
                                        $$VisualBiblesTableReferences
                                            ._primaryLensIdTable(db),
                                    referencedColumn:
                                        $$VisualBiblesTableReferences
                                            ._primaryLensIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (visualBibleColorBlocksRefs)
                        await $_getPrefetchedData<
                          VisualBible,
                          $VisualBiblesTable,
                          VisualBibleColorBlock
                        >(
                          currentTable: table,
                          referencedTable: $$VisualBiblesTableReferences
                              ._visualBibleColorBlocksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$VisualBiblesTableReferences(
                                db,
                                table,
                                p0,
                              ).visualBibleColorBlocksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.bibleId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (visualBibleLocationRefsRefs)
                        await $_getPrefetchedData<
                          VisualBible,
                          $VisualBiblesTable,
                          VisualBibleLocationRef
                        >(
                          currentTable: table,
                          referencedTable: $$VisualBiblesTableReferences
                              ._visualBibleLocationRefsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$VisualBiblesTableReferences(
                                db,
                                table,
                                p0,
                              ).visualBibleLocationRefsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.bibleId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (moodboardImagesRefs)
                        await $_getPrefetchedData<
                          VisualBible,
                          $VisualBiblesTable,
                          MoodboardImage
                        >(
                          currentTable: table,
                          referencedTable: $$VisualBiblesTableReferences
                              ._moodboardImagesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$VisualBiblesTableReferences(
                                db,
                                table,
                                p0,
                              ).moodboardImagesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.bibleId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$VisualBiblesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VisualBiblesTable,
      VisualBible,
      $$VisualBiblesTableFilterComposer,
      $$VisualBiblesTableOrderingComposer,
      $$VisualBiblesTableAnnotationComposer,
      $$VisualBiblesTableCreateCompanionBuilder,
      $$VisualBiblesTableUpdateCompanionBuilder,
      (VisualBible, $$VisualBiblesTableReferences),
      VisualBible,
      PrefetchHooks Function({
        bool projectId,
        bool primaryLensId,
        bool visualBibleColorBlocksRefs,
        bool visualBibleLocationRefsRefs,
        bool moodboardImagesRefs,
      })
    >;
typedef $$VisualBibleColorBlocksTableCreateCompanionBuilder =
    VisualBibleColorBlocksCompanion Function({
      Value<int> id,
      required int bibleId,
      required String blockName,
      Value<String?> emotionalIntent,
      required String dominantColors,
      Value<String?> accentColors,
      Value<String?> prohibitedColors,
      Value<int?> colorTempKelvin,
      Value<String?> referenceImages,
      Value<int> sortOrder,
    });
typedef $$VisualBibleColorBlocksTableUpdateCompanionBuilder =
    VisualBibleColorBlocksCompanion Function({
      Value<int> id,
      Value<int> bibleId,
      Value<String> blockName,
      Value<String?> emotionalIntent,
      Value<String> dominantColors,
      Value<String?> accentColors,
      Value<String?> prohibitedColors,
      Value<int?> colorTempKelvin,
      Value<String?> referenceImages,
      Value<int> sortOrder,
    });

final class $$VisualBibleColorBlocksTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $VisualBibleColorBlocksTable,
          VisualBibleColorBlock
        > {
  $$VisualBibleColorBlocksTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $VisualBiblesTable _bibleIdTable(_$AppDatabase db) =>
      db.visualBibles.createAlias(
        $_aliasNameGenerator(
          db.visualBibleColorBlocks.bibleId,
          db.visualBibles.id,
        ),
      );

  $$VisualBiblesTableProcessedTableManager get bibleId {
    final $_column = $_itemColumn<int>('bible_id')!;

    final manager = $$VisualBiblesTableTableManager(
      $_db,
      $_db.visualBibles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bibleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$VisualBibleColorBlocksTableFilterComposer
    extends Composer<_$AppDatabase, $VisualBibleColorBlocksTable> {
  $$VisualBibleColorBlocksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get blockName => $composableBuilder(
    column: $table.blockName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get emotionalIntent => $composableBuilder(
    column: $table.emotionalIntent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dominantColors => $composableBuilder(
    column: $table.dominantColors,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accentColors => $composableBuilder(
    column: $table.accentColors,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prohibitedColors => $composableBuilder(
    column: $table.prohibitedColors,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorTempKelvin => $composableBuilder(
    column: $table.colorTempKelvin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get referenceImages => $composableBuilder(
    column: $table.referenceImages,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  $$VisualBiblesTableFilterComposer get bibleId {
    final $$VisualBiblesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bibleId,
      referencedTable: $db.visualBibles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VisualBiblesTableFilterComposer(
            $db: $db,
            $table: $db.visualBibles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VisualBibleColorBlocksTableOrderingComposer
    extends Composer<_$AppDatabase, $VisualBibleColorBlocksTable> {
  $$VisualBibleColorBlocksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get blockName => $composableBuilder(
    column: $table.blockName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get emotionalIntent => $composableBuilder(
    column: $table.emotionalIntent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dominantColors => $composableBuilder(
    column: $table.dominantColors,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accentColors => $composableBuilder(
    column: $table.accentColors,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prohibitedColors => $composableBuilder(
    column: $table.prohibitedColors,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorTempKelvin => $composableBuilder(
    column: $table.colorTempKelvin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get referenceImages => $composableBuilder(
    column: $table.referenceImages,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  $$VisualBiblesTableOrderingComposer get bibleId {
    final $$VisualBiblesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bibleId,
      referencedTable: $db.visualBibles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VisualBiblesTableOrderingComposer(
            $db: $db,
            $table: $db.visualBibles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VisualBibleColorBlocksTableAnnotationComposer
    extends Composer<_$AppDatabase, $VisualBibleColorBlocksTable> {
  $$VisualBibleColorBlocksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get blockName =>
      $composableBuilder(column: $table.blockName, builder: (column) => column);

  GeneratedColumn<String> get emotionalIntent => $composableBuilder(
    column: $table.emotionalIntent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dominantColors => $composableBuilder(
    column: $table.dominantColors,
    builder: (column) => column,
  );

  GeneratedColumn<String> get accentColors => $composableBuilder(
    column: $table.accentColors,
    builder: (column) => column,
  );

  GeneratedColumn<String> get prohibitedColors => $composableBuilder(
    column: $table.prohibitedColors,
    builder: (column) => column,
  );

  GeneratedColumn<int> get colorTempKelvin => $composableBuilder(
    column: $table.colorTempKelvin,
    builder: (column) => column,
  );

  GeneratedColumn<String> get referenceImages => $composableBuilder(
    column: $table.referenceImages,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  $$VisualBiblesTableAnnotationComposer get bibleId {
    final $$VisualBiblesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bibleId,
      referencedTable: $db.visualBibles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VisualBiblesTableAnnotationComposer(
            $db: $db,
            $table: $db.visualBibles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VisualBibleColorBlocksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VisualBibleColorBlocksTable,
          VisualBibleColorBlock,
          $$VisualBibleColorBlocksTableFilterComposer,
          $$VisualBibleColorBlocksTableOrderingComposer,
          $$VisualBibleColorBlocksTableAnnotationComposer,
          $$VisualBibleColorBlocksTableCreateCompanionBuilder,
          $$VisualBibleColorBlocksTableUpdateCompanionBuilder,
          (VisualBibleColorBlock, $$VisualBibleColorBlocksTableReferences),
          VisualBibleColorBlock,
          PrefetchHooks Function({bool bibleId})
        > {
  $$VisualBibleColorBlocksTableTableManager(
    _$AppDatabase db,
    $VisualBibleColorBlocksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VisualBibleColorBlocksTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$VisualBibleColorBlocksTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$VisualBibleColorBlocksTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> bibleId = const Value.absent(),
                Value<String> blockName = const Value.absent(),
                Value<String?> emotionalIntent = const Value.absent(),
                Value<String> dominantColors = const Value.absent(),
                Value<String?> accentColors = const Value.absent(),
                Value<String?> prohibitedColors = const Value.absent(),
                Value<int?> colorTempKelvin = const Value.absent(),
                Value<String?> referenceImages = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => VisualBibleColorBlocksCompanion(
                id: id,
                bibleId: bibleId,
                blockName: blockName,
                emotionalIntent: emotionalIntent,
                dominantColors: dominantColors,
                accentColors: accentColors,
                prohibitedColors: prohibitedColors,
                colorTempKelvin: colorTempKelvin,
                referenceImages: referenceImages,
                sortOrder: sortOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int bibleId,
                required String blockName,
                Value<String?> emotionalIntent = const Value.absent(),
                required String dominantColors,
                Value<String?> accentColors = const Value.absent(),
                Value<String?> prohibitedColors = const Value.absent(),
                Value<int?> colorTempKelvin = const Value.absent(),
                Value<String?> referenceImages = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => VisualBibleColorBlocksCompanion.insert(
                id: id,
                bibleId: bibleId,
                blockName: blockName,
                emotionalIntent: emotionalIntent,
                dominantColors: dominantColors,
                accentColors: accentColors,
                prohibitedColors: prohibitedColors,
                colorTempKelvin: colorTempKelvin,
                referenceImages: referenceImages,
                sortOrder: sortOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$VisualBibleColorBlocksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({bibleId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (bibleId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.bibleId,
                                referencedTable:
                                    $$VisualBibleColorBlocksTableReferences
                                        ._bibleIdTable(db),
                                referencedColumn:
                                    $$VisualBibleColorBlocksTableReferences
                                        ._bibleIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$VisualBibleColorBlocksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VisualBibleColorBlocksTable,
      VisualBibleColorBlock,
      $$VisualBibleColorBlocksTableFilterComposer,
      $$VisualBibleColorBlocksTableOrderingComposer,
      $$VisualBibleColorBlocksTableAnnotationComposer,
      $$VisualBibleColorBlocksTableCreateCompanionBuilder,
      $$VisualBibleColorBlocksTableUpdateCompanionBuilder,
      (VisualBibleColorBlock, $$VisualBibleColorBlocksTableReferences),
      VisualBibleColorBlock,
      PrefetchHooks Function({bool bibleId})
    >;
typedef $$VisualBibleLocationRefsTableCreateCompanionBuilder =
    VisualBibleLocationRefsCompanion Function({
      Value<int> id,
      required int bibleId,
      required String locationName,
      Value<String?> lightingNote,
      Value<String?> colorNote,
      Value<String?> referenceImages,
      Value<String?> linkedShotIds,
    });
typedef $$VisualBibleLocationRefsTableUpdateCompanionBuilder =
    VisualBibleLocationRefsCompanion Function({
      Value<int> id,
      Value<int> bibleId,
      Value<String> locationName,
      Value<String?> lightingNote,
      Value<String?> colorNote,
      Value<String?> referenceImages,
      Value<String?> linkedShotIds,
    });

final class $$VisualBibleLocationRefsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $VisualBibleLocationRefsTable,
          VisualBibleLocationRef
        > {
  $$VisualBibleLocationRefsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $VisualBiblesTable _bibleIdTable(_$AppDatabase db) =>
      db.visualBibles.createAlias(
        $_aliasNameGenerator(
          db.visualBibleLocationRefs.bibleId,
          db.visualBibles.id,
        ),
      );

  $$VisualBiblesTableProcessedTableManager get bibleId {
    final $_column = $_itemColumn<int>('bible_id')!;

    final manager = $$VisualBiblesTableTableManager(
      $_db,
      $_db.visualBibles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bibleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$VisualBibleLocationRefsTableFilterComposer
    extends Composer<_$AppDatabase, $VisualBibleLocationRefsTable> {
  $$VisualBibleLocationRefsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locationName => $composableBuilder(
    column: $table.locationName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lightingNote => $composableBuilder(
    column: $table.lightingNote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorNote => $composableBuilder(
    column: $table.colorNote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get referenceImages => $composableBuilder(
    column: $table.referenceImages,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get linkedShotIds => $composableBuilder(
    column: $table.linkedShotIds,
    builder: (column) => ColumnFilters(column),
  );

  $$VisualBiblesTableFilterComposer get bibleId {
    final $$VisualBiblesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bibleId,
      referencedTable: $db.visualBibles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VisualBiblesTableFilterComposer(
            $db: $db,
            $table: $db.visualBibles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VisualBibleLocationRefsTableOrderingComposer
    extends Composer<_$AppDatabase, $VisualBibleLocationRefsTable> {
  $$VisualBibleLocationRefsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locationName => $composableBuilder(
    column: $table.locationName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lightingNote => $composableBuilder(
    column: $table.lightingNote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorNote => $composableBuilder(
    column: $table.colorNote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get referenceImages => $composableBuilder(
    column: $table.referenceImages,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get linkedShotIds => $composableBuilder(
    column: $table.linkedShotIds,
    builder: (column) => ColumnOrderings(column),
  );

  $$VisualBiblesTableOrderingComposer get bibleId {
    final $$VisualBiblesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bibleId,
      referencedTable: $db.visualBibles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VisualBiblesTableOrderingComposer(
            $db: $db,
            $table: $db.visualBibles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VisualBibleLocationRefsTableAnnotationComposer
    extends Composer<_$AppDatabase, $VisualBibleLocationRefsTable> {
  $$VisualBibleLocationRefsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get locationName => $composableBuilder(
    column: $table.locationName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lightingNote => $composableBuilder(
    column: $table.lightingNote,
    builder: (column) => column,
  );

  GeneratedColumn<String> get colorNote =>
      $composableBuilder(column: $table.colorNote, builder: (column) => column);

  GeneratedColumn<String> get referenceImages => $composableBuilder(
    column: $table.referenceImages,
    builder: (column) => column,
  );

  GeneratedColumn<String> get linkedShotIds => $composableBuilder(
    column: $table.linkedShotIds,
    builder: (column) => column,
  );

  $$VisualBiblesTableAnnotationComposer get bibleId {
    final $$VisualBiblesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bibleId,
      referencedTable: $db.visualBibles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VisualBiblesTableAnnotationComposer(
            $db: $db,
            $table: $db.visualBibles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VisualBibleLocationRefsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VisualBibleLocationRefsTable,
          VisualBibleLocationRef,
          $$VisualBibleLocationRefsTableFilterComposer,
          $$VisualBibleLocationRefsTableOrderingComposer,
          $$VisualBibleLocationRefsTableAnnotationComposer,
          $$VisualBibleLocationRefsTableCreateCompanionBuilder,
          $$VisualBibleLocationRefsTableUpdateCompanionBuilder,
          (VisualBibleLocationRef, $$VisualBibleLocationRefsTableReferences),
          VisualBibleLocationRef,
          PrefetchHooks Function({bool bibleId})
        > {
  $$VisualBibleLocationRefsTableTableManager(
    _$AppDatabase db,
    $VisualBibleLocationRefsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VisualBibleLocationRefsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$VisualBibleLocationRefsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$VisualBibleLocationRefsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> bibleId = const Value.absent(),
                Value<String> locationName = const Value.absent(),
                Value<String?> lightingNote = const Value.absent(),
                Value<String?> colorNote = const Value.absent(),
                Value<String?> referenceImages = const Value.absent(),
                Value<String?> linkedShotIds = const Value.absent(),
              }) => VisualBibleLocationRefsCompanion(
                id: id,
                bibleId: bibleId,
                locationName: locationName,
                lightingNote: lightingNote,
                colorNote: colorNote,
                referenceImages: referenceImages,
                linkedShotIds: linkedShotIds,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int bibleId,
                required String locationName,
                Value<String?> lightingNote = const Value.absent(),
                Value<String?> colorNote = const Value.absent(),
                Value<String?> referenceImages = const Value.absent(),
                Value<String?> linkedShotIds = const Value.absent(),
              }) => VisualBibleLocationRefsCompanion.insert(
                id: id,
                bibleId: bibleId,
                locationName: locationName,
                lightingNote: lightingNote,
                colorNote: colorNote,
                referenceImages: referenceImages,
                linkedShotIds: linkedShotIds,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$VisualBibleLocationRefsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({bibleId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (bibleId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.bibleId,
                                referencedTable:
                                    $$VisualBibleLocationRefsTableReferences
                                        ._bibleIdTable(db),
                                referencedColumn:
                                    $$VisualBibleLocationRefsTableReferences
                                        ._bibleIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$VisualBibleLocationRefsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VisualBibleLocationRefsTable,
      VisualBibleLocationRef,
      $$VisualBibleLocationRefsTableFilterComposer,
      $$VisualBibleLocationRefsTableOrderingComposer,
      $$VisualBibleLocationRefsTableAnnotationComposer,
      $$VisualBibleLocationRefsTableCreateCompanionBuilder,
      $$VisualBibleLocationRefsTableUpdateCompanionBuilder,
      (VisualBibleLocationRef, $$VisualBibleLocationRefsTableReferences),
      VisualBibleLocationRef,
      PrefetchHooks Function({bool bibleId})
    >;
typedef $$MoodboardImagesTableCreateCompanionBuilder =
    MoodboardImagesCompanion Function({
      Value<int> id,
      required int projectId,
      Value<int?> bibleId,
      required String imagePath,
      Value<String> source,
      Value<String?> category,
      Value<String?> caption,
      Value<String?> filmReference,
      Value<int?> linkedSceneId,
      Value<String?> linkedLocationName,
      Value<int> sortOrder,
    });
typedef $$MoodboardImagesTableUpdateCompanionBuilder =
    MoodboardImagesCompanion Function({
      Value<int> id,
      Value<int> projectId,
      Value<int?> bibleId,
      Value<String> imagePath,
      Value<String> source,
      Value<String?> category,
      Value<String?> caption,
      Value<String?> filmReference,
      Value<int?> linkedSceneId,
      Value<String?> linkedLocationName,
      Value<int> sortOrder,
    });

final class $$MoodboardImagesTableReferences
    extends
        BaseReferences<_$AppDatabase, $MoodboardImagesTable, MoodboardImage> {
  $$MoodboardImagesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias(
        $_aliasNameGenerator(db.moodboardImages.projectId, db.projects.id),
      );

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<int>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $VisualBiblesTable _bibleIdTable(_$AppDatabase db) =>
      db.visualBibles.createAlias(
        $_aliasNameGenerator(db.moodboardImages.bibleId, db.visualBibles.id),
      );

  $$VisualBiblesTableProcessedTableManager? get bibleId {
    final $_column = $_itemColumn<int>('bible_id');
    if ($_column == null) return null;
    final manager = $$VisualBiblesTableTableManager(
      $_db,
      $_db.visualBibles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bibleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MoodboardImagesTableFilterComposer
    extends Composer<_$AppDatabase, $MoodboardImagesTable> {
  $$MoodboardImagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get caption => $composableBuilder(
    column: $table.caption,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filmReference => $composableBuilder(
    column: $table.filmReference,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get linkedSceneId => $composableBuilder(
    column: $table.linkedSceneId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get linkedLocationName => $composableBuilder(
    column: $table.linkedLocationName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$VisualBiblesTableFilterComposer get bibleId {
    final $$VisualBiblesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bibleId,
      referencedTable: $db.visualBibles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VisualBiblesTableFilterComposer(
            $db: $db,
            $table: $db.visualBibles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MoodboardImagesTableOrderingComposer
    extends Composer<_$AppDatabase, $MoodboardImagesTable> {
  $$MoodboardImagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get caption => $composableBuilder(
    column: $table.caption,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filmReference => $composableBuilder(
    column: $table.filmReference,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get linkedSceneId => $composableBuilder(
    column: $table.linkedSceneId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get linkedLocationName => $composableBuilder(
    column: $table.linkedLocationName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$VisualBiblesTableOrderingComposer get bibleId {
    final $$VisualBiblesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bibleId,
      referencedTable: $db.visualBibles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VisualBiblesTableOrderingComposer(
            $db: $db,
            $table: $db.visualBibles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MoodboardImagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MoodboardImagesTable> {
  $$MoodboardImagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get caption =>
      $composableBuilder(column: $table.caption, builder: (column) => column);

  GeneratedColumn<String> get filmReference => $composableBuilder(
    column: $table.filmReference,
    builder: (column) => column,
  );

  GeneratedColumn<int> get linkedSceneId => $composableBuilder(
    column: $table.linkedSceneId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get linkedLocationName => $composableBuilder(
    column: $table.linkedLocationName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$VisualBiblesTableAnnotationComposer get bibleId {
    final $$VisualBiblesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bibleId,
      referencedTable: $db.visualBibles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VisualBiblesTableAnnotationComposer(
            $db: $db,
            $table: $db.visualBibles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MoodboardImagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MoodboardImagesTable,
          MoodboardImage,
          $$MoodboardImagesTableFilterComposer,
          $$MoodboardImagesTableOrderingComposer,
          $$MoodboardImagesTableAnnotationComposer,
          $$MoodboardImagesTableCreateCompanionBuilder,
          $$MoodboardImagesTableUpdateCompanionBuilder,
          (MoodboardImage, $$MoodboardImagesTableReferences),
          MoodboardImage,
          PrefetchHooks Function({bool projectId, bool bibleId})
        > {
  $$MoodboardImagesTableTableManager(
    _$AppDatabase db,
    $MoodboardImagesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MoodboardImagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MoodboardImagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MoodboardImagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> projectId = const Value.absent(),
                Value<int?> bibleId = const Value.absent(),
                Value<String> imagePath = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String?> caption = const Value.absent(),
                Value<String?> filmReference = const Value.absent(),
                Value<int?> linkedSceneId = const Value.absent(),
                Value<String?> linkedLocationName = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => MoodboardImagesCompanion(
                id: id,
                projectId: projectId,
                bibleId: bibleId,
                imagePath: imagePath,
                source: source,
                category: category,
                caption: caption,
                filmReference: filmReference,
                linkedSceneId: linkedSceneId,
                linkedLocationName: linkedLocationName,
                sortOrder: sortOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int projectId,
                Value<int?> bibleId = const Value.absent(),
                required String imagePath,
                Value<String> source = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String?> caption = const Value.absent(),
                Value<String?> filmReference = const Value.absent(),
                Value<int?> linkedSceneId = const Value.absent(),
                Value<String?> linkedLocationName = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => MoodboardImagesCompanion.insert(
                id: id,
                projectId: projectId,
                bibleId: bibleId,
                imagePath: imagePath,
                source: source,
                category: category,
                caption: caption,
                filmReference: filmReference,
                linkedSceneId: linkedSceneId,
                linkedLocationName: linkedLocationName,
                sortOrder: sortOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MoodboardImagesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({projectId = false, bibleId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (projectId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.projectId,
                                referencedTable:
                                    $$MoodboardImagesTableReferences
                                        ._projectIdTable(db),
                                referencedColumn:
                                    $$MoodboardImagesTableReferences
                                        ._projectIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (bibleId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.bibleId,
                                referencedTable:
                                    $$MoodboardImagesTableReferences
                                        ._bibleIdTable(db),
                                referencedColumn:
                                    $$MoodboardImagesTableReferences
                                        ._bibleIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MoodboardImagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MoodboardImagesTable,
      MoodboardImage,
      $$MoodboardImagesTableFilterComposer,
      $$MoodboardImagesTableOrderingComposer,
      $$MoodboardImagesTableAnnotationComposer,
      $$MoodboardImagesTableCreateCompanionBuilder,
      $$MoodboardImagesTableUpdateCompanionBuilder,
      (MoodboardImage, $$MoodboardImagesTableReferences),
      MoodboardImage,
      PrefetchHooks Function({bool projectId, bool bibleId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProjectGroupsTableTableManager get projectGroups =>
      $$ProjectGroupsTableTableManager(_db, _db.projectGroups);
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db, _db.projects);
  $$LocationSitesTableTableManager get locationSites =>
      $$LocationSitesTableTableManager(_db, _db.locationSites);
  $$LocationBasePlansTableTableManager get locationBasePlans =>
      $$LocationBasePlansTableTableManager(_db, _db.locationBasePlans);
  $$ScenesTableTableManager get scenes =>
      $$ScenesTableTableManager(_db, _db.scenes);
  $$ShotsTableTableManager get shots =>
      $$ShotsTableTableManager(_db, _db.shots);
  $$ShotReferencesTableTableManager get shotReferences =>
      $$ShotReferencesTableTableManager(_db, _db.shotReferences);
  $$CameraPlanElementsTableTableManager get cameraPlanElements =>
      $$CameraPlanElementsTableTableManager(_db, _db.cameraPlanElements);
  $$CameraPathPointsTableTableManager get cameraPathPoints =>
      $$CameraPathPointsTableTableManager(_db, _db.cameraPathPoints);
  $$LocationImagesTableTableManager get locationImages =>
      $$LocationImagesTableTableManager(_db, _db.locationImages);
  $$SiteImagesTableTableManager get siteImages =>
      $$SiteImagesTableTableManager(_db, _db.siteImages);
  $$CamerasTableTableManager get cameras =>
      $$CamerasTableTableManager(_db, _db.cameras);
  $$LensesTableTableManager get lenses =>
      $$LensesTableTableManager(_db, _db.lenses);
  $$LightsTableTableManager get lights =>
      $$LightsTableTableManager(_db, _db.lights);
  $$ProjectEquipmentTableTableManager get projectEquipment =>
      $$ProjectEquipmentTableTableManager(_db, _db.projectEquipment);
  $$LookBiblesTableTableManager get lookBibles =>
      $$LookBiblesTableTableManager(_db, _db.lookBibles);
  $$ProjectAnnotatedPdfsTableTableManager get projectAnnotatedPdfs =>
      $$ProjectAnnotatedPdfsTableTableManager(_db, _db.projectAnnotatedPdfs);
  $$VisualBiblesTableTableManager get visualBibles =>
      $$VisualBiblesTableTableManager(_db, _db.visualBibles);
  $$VisualBibleColorBlocksTableTableManager get visualBibleColorBlocks =>
      $$VisualBibleColorBlocksTableTableManager(
        _db,
        _db.visualBibleColorBlocks,
      );
  $$VisualBibleLocationRefsTableTableManager get visualBibleLocationRefs =>
      $$VisualBibleLocationRefsTableTableManager(
        _db,
        _db.visualBibleLocationRefs,
      );
  $$MoodboardImagesTableTableManager get moodboardImages =>
      $$MoodboardImagesTableTableManager(_db, _db.moodboardImages);
}
