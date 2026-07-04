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
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [id, name, sortOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'project_groups';
  @override
  VerificationContext validateIntegrity(Insertable<ProjectGroup> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProjectGroup map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProjectGroup(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
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
  const ProjectGroup(
      {required this.id, required this.name, required this.sortOrder});
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

  factory ProjectGroup.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
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

  ProjectGroupsCompanion copyWith(
      {Value<int>? id, Value<String>? name, Value<int>? sortOrder}) {
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
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _groupIdMeta =
      const VerificationMeta('groupId');
  @override
  late final GeneratedColumn<int> groupId = GeneratedColumn<int>(
      'group_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES project_groups (id)'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _directorMeta =
      const VerificationMeta('director');
  @override
  late final GeneratedColumn<String> director = GeneratedColumn<String>(
      'director', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _clientNameMeta =
      const VerificationMeta('clientName');
  @override
  late final GeneratedColumn<String> clientName = GeneratedColumn<String>(
      'client_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('preproduction'));
  static const VerificationMeta _iconCodeMeta =
      const VerificationMeta('iconCode');
  @override
  late final GeneratedColumn<int> iconCode = GeneratedColumn<int>(
      'icon_code', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0xe3f4));
  static const VerificationMeta _coverImagePathMeta =
      const VerificationMeta('coverImagePath');
  @override
  late final GeneratedColumn<String> coverImagePath = GeneratedColumn<String>(
      'cover_image_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _shootingStartDateMeta =
      const VerificationMeta('shootingStartDate');
  @override
  late final GeneratedColumn<String> shootingStartDate =
      GeneratedColumn<String>('shooting_start_date', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _shootingEndDateMeta =
      const VerificationMeta('shootingEndDate');
  @override
  late final GeneratedColumn<String> shootingEndDate = GeneratedColumn<String>(
      'shooting_end_date', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _googleEmailMeta =
      const VerificationMeta('googleEmail');
  @override
  late final GeneratedColumn<String> googleEmail = GeneratedColumn<String>(
      'google_email', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _scriptFilePathMeta =
      const VerificationMeta('scriptFilePath');
  @override
  late final GeneratedColumn<String> scriptFilePath = GeneratedColumn<String>(
      'script_file_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _scriptFileNameMeta =
      const VerificationMeta('scriptFileName');
  @override
  late final GeneratedColumn<String> scriptFileName = GeneratedColumn<String>(
      'script_file_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
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
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'projects';
  @override
  VerificationContext validateIntegrity(Insertable<Project> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta,
          groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('director')) {
      context.handle(_directorMeta,
          director.isAcceptableOrUnknown(data['director']!, _directorMeta));
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('client_name')) {
      context.handle(
          _clientNameMeta,
          clientName.isAcceptableOrUnknown(
              data['client_name']!, _clientNameMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('icon_code')) {
      context.handle(_iconCodeMeta,
          iconCode.isAcceptableOrUnknown(data['icon_code']!, _iconCodeMeta));
    }
    if (data.containsKey('cover_image_path')) {
      context.handle(
          _coverImagePathMeta,
          coverImagePath.isAcceptableOrUnknown(
              data['cover_image_path']!, _coverImagePathMeta));
    }
    if (data.containsKey('shooting_start_date')) {
      context.handle(
          _shootingStartDateMeta,
          shootingStartDate.isAcceptableOrUnknown(
              data['shooting_start_date']!, _shootingStartDateMeta));
    }
    if (data.containsKey('shooting_end_date')) {
      context.handle(
          _shootingEndDateMeta,
          shootingEndDate.isAcceptableOrUnknown(
              data['shooting_end_date']!, _shootingEndDateMeta));
    }
    if (data.containsKey('google_email')) {
      context.handle(
          _googleEmailMeta,
          googleEmail.isAcceptableOrUnknown(
              data['google_email']!, _googleEmailMeta));
    }
    if (data.containsKey('script_file_path')) {
      context.handle(
          _scriptFilePathMeta,
          scriptFilePath.isAcceptableOrUnknown(
              data['script_file_path']!, _scriptFilePathMeta));
    }
    if (data.containsKey('script_file_name')) {
      context.handle(
          _scriptFileNameMeta,
          scriptFileName.isAcceptableOrUnknown(
              data['script_file_name']!, _scriptFileNameMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Project map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Project(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      groupId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}group_id']),
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      director: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}director']),
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      clientName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}client_name']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      iconCode: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}icon_code'])!,
      coverImagePath: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}cover_image_path']),
      shootingStartDate: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}shooting_start_date']),
      shootingEndDate: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}shooting_end_date']),
      googleEmail: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}google_email']),
      scriptFilePath: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}script_file_path']),
      scriptFileName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}script_file_name']),
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
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
  const Project(
      {required this.id,
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
      required this.updatedAt});
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

  factory Project.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
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
      shootingStartDate:
          serializer.fromJson<String?>(json['shootingStartDate']),
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

  Project copyWith(
          {int? id,
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
          DateTime? updatedAt}) =>
      Project(
        id: id ?? this.id,
        groupId: groupId.present ? groupId.value : this.groupId,
        name: name ?? this.name,
        director: director.present ? director.value : this.director,
        description: description.present ? description.value : this.description,
        clientName: clientName.present ? clientName.value : this.clientName,
        status: status ?? this.status,
        iconCode: iconCode ?? this.iconCode,
        coverImagePath:
            coverImagePath.present ? coverImagePath.value : this.coverImagePath,
        shootingStartDate: shootingStartDate.present
            ? shootingStartDate.value
            : this.shootingStartDate,
        shootingEndDate: shootingEndDate.present
            ? shootingEndDate.value
            : this.shootingEndDate,
        googleEmail: googleEmail.present ? googleEmail.value : this.googleEmail,
        scriptFilePath:
            scriptFilePath.present ? scriptFilePath.value : this.scriptFilePath,
        scriptFileName:
            scriptFileName.present ? scriptFileName.value : this.scriptFileName,
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
      description:
          data.description.present ? data.description.value : this.description,
      clientName:
          data.clientName.present ? data.clientName.value : this.clientName,
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
      googleEmail:
          data.googleEmail.present ? data.googleEmail.value : this.googleEmail,
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
      updatedAt);
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

  ProjectsCompanion copyWith(
      {Value<int>? id,
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
      Value<DateTime>? updatedAt}) {
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
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _projectIdMeta =
      const VerificationMeta('projectId');
  @override
  late final GeneratedColumn<int> projectId = GeneratedColumn<int>(
      'project_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES projects (id)'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _floorPlanJsonMeta =
      const VerificationMeta('floorPlanJson');
  @override
  late final GeneratedColumn<String> floorPlanJson = GeneratedColumn<String>(
      'floor_plan_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _scanPathMeta =
      const VerificationMeta('scanPath');
  @override
  late final GeneratedColumn<String> scanPath = GeneratedColumn<String>(
      'scan_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _scanSourceMeta =
      const VerificationMeta('scanSource');
  @override
  late final GeneratedColumn<String> scanSource = GeneratedColumn<String>(
      'scan_source', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _scanMetadataJsonMeta =
      const VerificationMeta('scanMetadataJson');
  @override
  late final GeneratedColumn<String> scanMetadataJson = GeneratedColumn<String>(
      'scan_metadata_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
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
        sortOrder
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'location_sites';
  @override
  VerificationContext validateIntegrity(Insertable<LocationSite> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('project_id')) {
      context.handle(_projectIdMeta,
          projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta));
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('floor_plan_json')) {
      context.handle(
          _floorPlanJsonMeta,
          floorPlanJson.isAcceptableOrUnknown(
              data['floor_plan_json']!, _floorPlanJsonMeta));
    }
    if (data.containsKey('scan_path')) {
      context.handle(_scanPathMeta,
          scanPath.isAcceptableOrUnknown(data['scan_path']!, _scanPathMeta));
    }
    if (data.containsKey('scan_source')) {
      context.handle(
          _scanSourceMeta,
          scanSource.isAcceptableOrUnknown(
              data['scan_source']!, _scanSourceMeta));
    }
    if (data.containsKey('scan_metadata_json')) {
      context.handle(
          _scanMetadataJsonMeta,
          scanMetadataJson.isAcceptableOrUnknown(
              data['scan_metadata_json']!, _scanMetadataJsonMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocationSite map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocationSite(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      projectId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}project_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      floorPlanJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}floor_plan_json']),
      scanPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}scan_path']),
      scanSource: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}scan_source']),
      scanMetadataJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}scan_metadata_json']),
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
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
  const LocationSite(
      {required this.id,
      required this.projectId,
      required this.name,
      this.description,
      this.notes,
      this.floorPlanJson,
      this.scanPath,
      this.scanSource,
      this.scanMetadataJson,
      required this.sortOrder});
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
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
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

  factory LocationSite.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
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

  LocationSite copyWith(
          {int? id,
          int? projectId,
          String? name,
          Value<String?> description = const Value.absent(),
          Value<String?> notes = const Value.absent(),
          Value<String?> floorPlanJson = const Value.absent(),
          Value<String?> scanPath = const Value.absent(),
          Value<String?> scanSource = const Value.absent(),
          Value<String?> scanMetadataJson = const Value.absent(),
          int? sortOrder}) =>
      LocationSite(
        id: id ?? this.id,
        projectId: projectId ?? this.projectId,
        name: name ?? this.name,
        description: description.present ? description.value : this.description,
        notes: notes.present ? notes.value : this.notes,
        floorPlanJson:
            floorPlanJson.present ? floorPlanJson.value : this.floorPlanJson,
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
      description:
          data.description.present ? data.description.value : this.description,
      notes: data.notes.present ? data.notes.value : this.notes,
      floorPlanJson: data.floorPlanJson.present
          ? data.floorPlanJson.value
          : this.floorPlanJson,
      scanPath: data.scanPath.present ? data.scanPath.value : this.scanPath,
      scanSource:
          data.scanSource.present ? data.scanSource.value : this.scanSource,
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
  int get hashCode => Object.hash(id, projectId, name, description, notes,
      floorPlanJson, scanPath, scanSource, scanMetadataJson, sortOrder);
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
  })  : projectId = Value(projectId),
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

  LocationSitesCompanion copyWith(
      {Value<int>? id,
      Value<int>? projectId,
      Value<String>? name,
      Value<String?>? description,
      Value<String?>? notes,
      Value<String?>? floorPlanJson,
      Value<String?>? scanPath,
      Value<String?>? scanSource,
      Value<String?>? scanMetadataJson,
      Value<int>? sortOrder}) {
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
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _projectIdMeta =
      const VerificationMeta('projectId');
  @override
  late final GeneratedColumn<int> projectId = GeneratedColumn<int>(
      'project_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES projects (id)'));
  static const VerificationMeta _siteIdMeta = const VerificationMeta('siteId');
  @override
  late final GeneratedColumn<int> siteId = GeneratedColumn<int>(
      'site_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES location_sites (id)'));
  static const VerificationMeta _locationNameMeta =
      const VerificationMeta('locationName');
  @override
  late final GeneratedColumn<String> locationName = GeneratedColumn<String>(
      'location_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _imagePathMeta =
      const VerificationMeta('imagePath');
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
      'image_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
      'color', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('#94A3B8'));
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _model3dPathMeta =
      const VerificationMeta('model3dPath');
  @override
  late final GeneratedColumn<String> model3dPath = GeneratedColumn<String>(
      'model3d_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _floorPlanJsonMeta =
      const VerificationMeta('floorPlanJson');
  @override
  late final GeneratedColumn<String> floorPlanJson = GeneratedColumn<String>(
      'floor_plan_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _scanPathMeta =
      const VerificationMeta('scanPath');
  @override
  late final GeneratedColumn<String> scanPath = GeneratedColumn<String>(
      'scan_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _scanSourceMeta =
      const VerificationMeta('scanSource');
  @override
  late final GeneratedColumn<String> scanSource = GeneratedColumn<String>(
      'scan_source', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _scanMetadataJsonMeta =
      const VerificationMeta('scanMetadataJson');
  @override
  late final GeneratedColumn<String> scanMetadataJson = GeneratedColumn<String>(
      'scan_metadata_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
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
        sortOrder
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'location_base_plans';
  @override
  VerificationContext validateIntegrity(Insertable<LocationBasePlan> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('project_id')) {
      context.handle(_projectIdMeta,
          projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta));
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('site_id')) {
      context.handle(_siteIdMeta,
          siteId.isAcceptableOrUnknown(data['site_id']!, _siteIdMeta));
    }
    if (data.containsKey('location_name')) {
      context.handle(
          _locationNameMeta,
          locationName.isAcceptableOrUnknown(
              data['location_name']!, _locationNameMeta));
    } else if (isInserting) {
      context.missing(_locationNameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('image_path')) {
      context.handle(_imagePathMeta,
          imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta));
    }
    if (data.containsKey('color')) {
      context.handle(
          _colorMeta, color.isAcceptableOrUnknown(data['color']!, _colorMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('model3d_path')) {
      context.handle(
          _model3dPathMeta,
          model3dPath.isAcceptableOrUnknown(
              data['model3d_path']!, _model3dPathMeta));
    }
    if (data.containsKey('floor_plan_json')) {
      context.handle(
          _floorPlanJsonMeta,
          floorPlanJson.isAcceptableOrUnknown(
              data['floor_plan_json']!, _floorPlanJsonMeta));
    }
    if (data.containsKey('scan_path')) {
      context.handle(_scanPathMeta,
          scanPath.isAcceptableOrUnknown(data['scan_path']!, _scanPathMeta));
    }
    if (data.containsKey('scan_source')) {
      context.handle(
          _scanSourceMeta,
          scanSource.isAcceptableOrUnknown(
              data['scan_source']!, _scanSourceMeta));
    }
    if (data.containsKey('scan_metadata_json')) {
      context.handle(
          _scanMetadataJsonMeta,
          scanMetadataJson.isAcceptableOrUnknown(
              data['scan_metadata_json']!, _scanMetadataJsonMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocationBasePlan map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocationBasePlan(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      projectId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}project_id'])!,
      siteId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}site_id']),
      locationName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}location_name'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      imagePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_path']),
      color: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}color'])!,
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      model3dPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}model3d_path']),
      floorPlanJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}floor_plan_json']),
      scanPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}scan_path']),
      scanSource: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}scan_source']),
      scanMetadataJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}scan_metadata_json']),
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
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
  const LocationBasePlan(
      {required this.id,
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
      required this.sortOrder});
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
      siteId:
          siteId == null && nullToAbsent ? const Value.absent() : Value(siteId),
      locationName: Value(locationName),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      imagePath: imagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(imagePath),
      color: Value(color),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
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

  factory LocationBasePlan.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
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

  LocationBasePlan copyWith(
          {int? id,
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
          int? sortOrder}) =>
      LocationBasePlan(
        id: id ?? this.id,
        projectId: projectId ?? this.projectId,
        siteId: siteId.present ? siteId.value : this.siteId,
        locationName: locationName ?? this.locationName,
        description: description.present ? description.value : this.description,
        imagePath: imagePath.present ? imagePath.value : this.imagePath,
        color: color ?? this.color,
        notes: notes.present ? notes.value : this.notes,
        model3dPath: model3dPath.present ? model3dPath.value : this.model3dPath,
        floorPlanJson:
            floorPlanJson.present ? floorPlanJson.value : this.floorPlanJson,
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
      description:
          data.description.present ? data.description.value : this.description,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      color: data.color.present ? data.color.value : this.color,
      notes: data.notes.present ? data.notes.value : this.notes,
      model3dPath:
          data.model3dPath.present ? data.model3dPath.value : this.model3dPath,
      floorPlanJson: data.floorPlanJson.present
          ? data.floorPlanJson.value
          : this.floorPlanJson,
      scanPath: data.scanPath.present ? data.scanPath.value : this.scanPath,
      scanSource:
          data.scanSource.present ? data.scanSource.value : this.scanSource,
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
      sortOrder);
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
  })  : projectId = Value(projectId),
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

  LocationBasePlansCompanion copyWith(
      {Value<int>? id,
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
      Value<int>? sortOrder}) {
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
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _projectIdMeta =
      const VerificationMeta('projectId');
  @override
  late final GeneratedColumn<int> projectId = GeneratedColumn<int>(
      'project_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES projects (id)'));
  static const VerificationMeta _numberMeta = const VerificationMeta('number');
  @override
  late final GeneratedColumn<int> number = GeneratedColumn<int>(
      'number', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _locationCanonicalMeta =
      const VerificationMeta('locationCanonical');
  @override
  late final GeneratedColumn<String> locationCanonical =
      GeneratedColumn<String>('location_canonical', aliasedName, false,
          type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _locationPureNameMeta =
      const VerificationMeta('locationPureName');
  @override
  late final GeneratedColumn<String> locationPureName = GeneratedColumn<String>(
      'location_pure_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _locationSiteIdMeta =
      const VerificationMeta('locationSiteId');
  @override
  late final GeneratedColumn<int> locationSiteId = GeneratedColumn<int>(
      'location_site_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES location_sites (id)'));
  static const VerificationMeta _locationIdMeta =
      const VerificationMeta('locationId');
  @override
  late final GeneratedColumn<int> locationId = GeneratedColumn<int>(
      'location_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES location_base_plans (id)'));
  static const VerificationMeta _intExtMeta = const VerificationMeta('intExt');
  @override
  late final GeneratedColumn<String> intExt = GeneratedColumn<String>(
      'int_ext', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('EXT'));
  static const VerificationMeta _dayNightMeta =
      const VerificationMeta('dayNight');
  @override
  late final GeneratedColumn<String> dayNight = GeneratedColumn<String>(
      'day_night', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('DÍA'));
  static const VerificationMeta _locationColorMeta =
      const VerificationMeta('locationColor');
  @override
  late final GeneratedColumn<String> locationColor = GeneratedColumn<String>(
      'location_color', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _actionTextMeta =
      const VerificationMeta('actionText');
  @override
  late final GeneratedColumn<String> actionText = GeneratedColumn<String>(
      'action_text', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sourceStartIndexMeta =
      const VerificationMeta('sourceStartIndex');
  @override
  late final GeneratedColumn<int> sourceStartIndex = GeneratedColumn<int>(
      'source_start_index', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _durationMinutesMeta =
      const VerificationMeta('durationMinutes');
  @override
  late final GeneratedColumn<int> durationMinutes = GeneratedColumn<int>(
      'duration_minutes', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _autoNumberingMeta =
      const VerificationMeta('autoNumbering');
  @override
  late final GeneratedColumn<bool> autoNumbering = GeneratedColumn<bool>(
      'auto_numbering', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("auto_numbering" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
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
        sortOrder
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scenes';
  @override
  VerificationContext validateIntegrity(Insertable<Scene> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('project_id')) {
      context.handle(_projectIdMeta,
          projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta));
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('number')) {
      context.handle(_numberMeta,
          number.isAcceptableOrUnknown(data['number']!, _numberMeta));
    } else if (isInserting) {
      context.missing(_numberMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('location_canonical')) {
      context.handle(
          _locationCanonicalMeta,
          locationCanonical.isAcceptableOrUnknown(
              data['location_canonical']!, _locationCanonicalMeta));
    } else if (isInserting) {
      context.missing(_locationCanonicalMeta);
    }
    if (data.containsKey('location_pure_name')) {
      context.handle(
          _locationPureNameMeta,
          locationPureName.isAcceptableOrUnknown(
              data['location_pure_name']!, _locationPureNameMeta));
    } else if (isInserting) {
      context.missing(_locationPureNameMeta);
    }
    if (data.containsKey('location_site_id')) {
      context.handle(
          _locationSiteIdMeta,
          locationSiteId.isAcceptableOrUnknown(
              data['location_site_id']!, _locationSiteIdMeta));
    }
    if (data.containsKey('location_id')) {
      context.handle(
          _locationIdMeta,
          locationId.isAcceptableOrUnknown(
              data['location_id']!, _locationIdMeta));
    }
    if (data.containsKey('int_ext')) {
      context.handle(_intExtMeta,
          intExt.isAcceptableOrUnknown(data['int_ext']!, _intExtMeta));
    }
    if (data.containsKey('day_night')) {
      context.handle(_dayNightMeta,
          dayNight.isAcceptableOrUnknown(data['day_night']!, _dayNightMeta));
    }
    if (data.containsKey('location_color')) {
      context.handle(
          _locationColorMeta,
          locationColor.isAcceptableOrUnknown(
              data['location_color']!, _locationColorMeta));
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('action_text')) {
      context.handle(
          _actionTextMeta,
          actionText.isAcceptableOrUnknown(
              data['action_text']!, _actionTextMeta));
    }
    if (data.containsKey('source_start_index')) {
      context.handle(
          _sourceStartIndexMeta,
          sourceStartIndex.isAcceptableOrUnknown(
              data['source_start_index']!, _sourceStartIndexMeta));
    }
    if (data.containsKey('duration_minutes')) {
      context.handle(
          _durationMinutesMeta,
          durationMinutes.isAcceptableOrUnknown(
              data['duration_minutes']!, _durationMinutesMeta));
    }
    if (data.containsKey('auto_numbering')) {
      context.handle(
          _autoNumberingMeta,
          autoNumbering.isAcceptableOrUnknown(
              data['auto_numbering']!, _autoNumberingMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Scene map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Scene(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      projectId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}project_id'])!,
      number: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}number'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      locationCanonical: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}location_canonical'])!,
      locationPureName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}location_pure_name'])!,
      locationSiteId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}location_site_id']),
      locationId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}location_id']),
      intExt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}int_ext'])!,
      dayNight: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}day_night'])!,
      locationColor: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}location_color']),
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      actionText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}action_text']),
      sourceStartIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}source_start_index']),
      durationMinutes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_minutes'])!,
      autoNumbering: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}auto_numbering'])!,
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
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
  const Scene(
      {required this.id,
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
      required this.sortOrder});
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

  factory Scene.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
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

  Scene copyWith(
          {int? id,
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
          int? sortOrder}) =>
      Scene(
        id: id ?? this.id,
        projectId: projectId ?? this.projectId,
        number: number ?? this.number,
        name: name ?? this.name,
        locationCanonical: locationCanonical ?? this.locationCanonical,
        locationPureName: locationPureName ?? this.locationPureName,
        locationSiteId:
            locationSiteId.present ? locationSiteId.value : this.locationSiteId,
        locationId: locationId.present ? locationId.value : this.locationId,
        intExt: intExt ?? this.intExt,
        dayNight: dayNight ?? this.dayNight,
        locationColor:
            locationColor.present ? locationColor.value : this.locationColor,
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
      locationId:
          data.locationId.present ? data.locationId.value : this.locationId,
      intExt: data.intExt.present ? data.intExt.value : this.intExt,
      dayNight: data.dayNight.present ? data.dayNight.value : this.dayNight,
      locationColor: data.locationColor.present
          ? data.locationColor.value
          : this.locationColor,
      description:
          data.description.present ? data.description.value : this.description,
      actionText:
          data.actionText.present ? data.actionText.value : this.actionText,
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
      sortOrder);
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
  })  : projectId = Value(projectId),
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

  ScenesCompanion copyWith(
      {Value<int>? id,
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
      Value<int>? sortOrder}) {
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
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _sceneIdMeta =
      const VerificationMeta('sceneId');
  @override
  late final GeneratedColumn<int> sceneId = GeneratedColumn<int>(
      'scene_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES scenes (id)'));
  static const VerificationMeta _projectIdMeta =
      const VerificationMeta('projectId');
  @override
  late final GeneratedColumn<int> projectId = GeneratedColumn<int>(
      'project_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES projects (id)'));
  static const VerificationMeta _numberMeta = const VerificationMeta('number');
  @override
  late final GeneratedColumn<int> number = GeneratedColumn<int>(
      'number', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _framingMeta =
      const VerificationMeta('framing');
  @override
  late final GeneratedColumn<String> framing = GeneratedColumn<String>(
      'framing', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lensMeta = const VerificationMeta('lens');
  @override
  late final GeneratedColumn<String> lens = GeneratedColumn<String>(
      'lens', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _angleMeta = const VerificationMeta('angle');
  @override
  late final GeneratedColumn<String> angle = GeneratedColumn<String>(
      'angle', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _movementMeta =
      const VerificationMeta('movement');
  @override
  late final GeneratedColumn<String> movement = GeneratedColumn<String>(
      'movement', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _fStopMeta = const VerificationMeta('fStop');
  @override
  late final GeneratedColumn<String> fStop = GeneratedColumn<String>(
      'f_stop', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _shutterAngleMeta =
      const VerificationMeta('shutterAngle');
  @override
  late final GeneratedColumn<String> shutterAngle = GeneratedColumn<String>(
      'shutter_angle', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _fpsMeta = const VerificationMeta('fps');
  @override
  late final GeneratedColumn<int> fps = GeneratedColumn<int>(
      'fps', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
      'action', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _notesHighlightMeta =
      const VerificationMeta('notesHighlight');
  @override
  late final GeneratedColumn<String> notesHighlight = GeneratedColumn<String>(
      'notes_highlight', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _referenceImagePathMeta =
      const VerificationMeta('referenceImagePath');
  @override
  late final GeneratedColumn<String> referenceImagePath =
      GeneratedColumn<String>('reference_image_path', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cameraPlanImagePathMeta =
      const VerificationMeta('cameraPlanImagePath');
  @override
  late final GeneratedColumn<String> cameraPlanImagePath =
      GeneratedColumn<String>('camera_plan_image_path', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _autoNumberingMeta =
      const VerificationMeta('autoNumbering');
  @override
  late final GeneratedColumn<bool> autoNumbering = GeneratedColumn<bool>(
      'auto_numbering', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("auto_numbering" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
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
        sortOrder
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shots';
  @override
  VerificationContext validateIntegrity(Insertable<Shot> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('scene_id')) {
      context.handle(_sceneIdMeta,
          sceneId.isAcceptableOrUnknown(data['scene_id']!, _sceneIdMeta));
    } else if (isInserting) {
      context.missing(_sceneIdMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(_projectIdMeta,
          projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta));
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('number')) {
      context.handle(_numberMeta,
          number.isAcceptableOrUnknown(data['number']!, _numberMeta));
    } else if (isInserting) {
      context.missing(_numberMeta);
    }
    if (data.containsKey('framing')) {
      context.handle(_framingMeta,
          framing.isAcceptableOrUnknown(data['framing']!, _framingMeta));
    }
    if (data.containsKey('lens')) {
      context.handle(
          _lensMeta, lens.isAcceptableOrUnknown(data['lens']!, _lensMeta));
    }
    if (data.containsKey('angle')) {
      context.handle(
          _angleMeta, angle.isAcceptableOrUnknown(data['angle']!, _angleMeta));
    }
    if (data.containsKey('movement')) {
      context.handle(_movementMeta,
          movement.isAcceptableOrUnknown(data['movement']!, _movementMeta));
    }
    if (data.containsKey('f_stop')) {
      context.handle(
          _fStopMeta, fStop.isAcceptableOrUnknown(data['f_stop']!, _fStopMeta));
    }
    if (data.containsKey('shutter_angle')) {
      context.handle(
          _shutterAngleMeta,
          shutterAngle.isAcceptableOrUnknown(
              data['shutter_angle']!, _shutterAngleMeta));
    }
    if (data.containsKey('fps')) {
      context.handle(
          _fpsMeta, fps.isAcceptableOrUnknown(data['fps']!, _fpsMeta));
    }
    if (data.containsKey('action')) {
      context.handle(_actionMeta,
          action.isAcceptableOrUnknown(data['action']!, _actionMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('notes_highlight')) {
      context.handle(
          _notesHighlightMeta,
          notesHighlight.isAcceptableOrUnknown(
              data['notes_highlight']!, _notesHighlightMeta));
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('reference_image_path')) {
      context.handle(
          _referenceImagePathMeta,
          referenceImagePath.isAcceptableOrUnknown(
              data['reference_image_path']!, _referenceImagePathMeta));
    }
    if (data.containsKey('camera_plan_image_path')) {
      context.handle(
          _cameraPlanImagePathMeta,
          cameraPlanImagePath.isAcceptableOrUnknown(
              data['camera_plan_image_path']!, _cameraPlanImagePathMeta));
    }
    if (data.containsKey('auto_numbering')) {
      context.handle(
          _autoNumberingMeta,
          autoNumbering.isAcceptableOrUnknown(
              data['auto_numbering']!, _autoNumberingMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Shot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Shot(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      sceneId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}scene_id'])!,
      projectId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}project_id'])!,
      number: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}number'])!,
      framing: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}framing']),
      lens: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}lens']),
      angle: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}angle']),
      movement: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}movement']),
      fStop: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}f_stop']),
      shutterAngle: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}shutter_angle']),
      fps: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}fps']),
      action: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}action']),
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      notesHighlight: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes_highlight']),
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      referenceImagePath: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}reference_image_path']),
      cameraPlanImagePath: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}camera_plan_image_path']),
      autoNumbering: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}auto_numbering'])!,
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
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
  const Shot(
      {required this.id,
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
      required this.sortOrder});
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
      angle:
          angle == null && nullToAbsent ? const Value.absent() : Value(angle),
      movement: movement == null && nullToAbsent
          ? const Value.absent()
          : Value(movement),
      fStop:
          fStop == null && nullToAbsent ? const Value.absent() : Value(fStop),
      shutterAngle: shutterAngle == null && nullToAbsent
          ? const Value.absent()
          : Value(shutterAngle),
      fps: fps == null && nullToAbsent ? const Value.absent() : Value(fps),
      action:
          action == null && nullToAbsent ? const Value.absent() : Value(action),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
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

  factory Shot.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
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
      referenceImagePath:
          serializer.fromJson<String?>(json['referenceImagePath']),
      cameraPlanImagePath:
          serializer.fromJson<String?>(json['cameraPlanImagePath']),
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

  Shot copyWith(
          {int? id,
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
          int? sortOrder}) =>
      Shot(
        id: id ?? this.id,
        sceneId: sceneId ?? this.sceneId,
        projectId: projectId ?? this.projectId,
        number: number ?? this.number,
        framing: framing.present ? framing.value : this.framing,
        lens: lens.present ? lens.value : this.lens,
        angle: angle.present ? angle.value : this.angle,
        movement: movement.present ? movement.value : this.movement,
        fStop: fStop.present ? fStop.value : this.fStop,
        shutterAngle:
            shutterAngle.present ? shutterAngle.value : this.shutterAngle,
        fps: fps.present ? fps.value : this.fps,
        action: action.present ? action.value : this.action,
        notes: notes.present ? notes.value : this.notes,
        notesHighlight:
            notesHighlight.present ? notesHighlight.value : this.notesHighlight,
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
      description:
          data.description.present ? data.description.value : this.description,
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
      sortOrder);
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
  })  : sceneId = Value(sceneId),
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

  ShotsCompanion copyWith(
      {Value<int>? id,
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
      Value<int>? sortOrder}) {
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
      map['camera_plan_image_path'] =
          Variable<String>(cameraPlanImagePath.value);
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
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _shotIdMeta = const VerificationMeta('shotId');
  @override
  late final GeneratedColumn<int> shotId = GeneratedColumn<int>(
      'shot_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES shots (id)'));
  static const VerificationMeta _imagePathMeta =
      const VerificationMeta('imagePath');
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
      'image_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('manual'));
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns =>
      [id, shotId, imagePath, source, sortOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shot_references';
  @override
  VerificationContext validateIntegrity(Insertable<ShotReference> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('shot_id')) {
      context.handle(_shotIdMeta,
          shotId.isAcceptableOrUnknown(data['shot_id']!, _shotIdMeta));
    } else if (isInserting) {
      context.missing(_shotIdMeta);
    }
    if (data.containsKey('image_path')) {
      context.handle(_imagePathMeta,
          imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta));
    } else if (isInserting) {
      context.missing(_imagePathMeta);
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ShotReference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShotReference(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      shotId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}shot_id'])!,
      imagePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_path'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
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
  const ShotReference(
      {required this.id,
      required this.shotId,
      required this.imagePath,
      required this.source,
      required this.sortOrder});
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

  factory ShotReference.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
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

  ShotReference copyWith(
          {int? id,
          int? shotId,
          String? imagePath,
          String? source,
          int? sortOrder}) =>
      ShotReference(
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
  })  : shotId = Value(shotId),
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

  ShotReferencesCompanion copyWith(
      {Value<int>? id,
      Value<int>? shotId,
      Value<String>? imagePath,
      Value<String>? source,
      Value<int>? sortOrder}) {
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
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _shotIdMeta = const VerificationMeta('shotId');
  @override
  late final GeneratedColumn<int> shotId = GeneratedColumn<int>(
      'shot_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES shots (id)'));
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _xMeta = const VerificationMeta('x');
  @override
  late final GeneratedColumn<double> x = GeneratedColumn<double>(
      'x', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _yMeta = const VerificationMeta('y');
  @override
  late final GeneratedColumn<double> y = GeneratedColumn<double>(
      'y', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _rotationMeta =
      const VerificationMeta('rotation');
  @override
  late final GeneratedColumn<double> rotation = GeneratedColumn<double>(
      'rotation', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
      'label', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
      'color', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cameraStabilizationMeta =
      const VerificationMeta('cameraStabilization');
  @override
  late final GeneratedColumn<String> cameraStabilization =
      GeneratedColumn<String>('camera_stabilization', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cameraLensMeta =
      const VerificationMeta('cameraLens');
  @override
  late final GeneratedColumn<String> cameraLens = GeneratedColumn<String>(
      'camera_lens', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cameraLetterMeta =
      const VerificationMeta('cameraLetter');
  @override
  late final GeneratedColumn<String> cameraLetter = GeneratedColumn<String>(
      'camera_letter', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('A'));
  static const VerificationMeta _cameraNumberMeta =
      const VerificationMeta('cameraNumber');
  @override
  late final GeneratedColumn<int> cameraNumber = GeneratedColumn<int>(
      'camera_number', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _lightTypeMeta =
      const VerificationMeta('lightType');
  @override
  late final GeneratedColumn<String> lightType = GeneratedColumn<String>(
      'light_type', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lukaCompatibleMeta =
      const VerificationMeta('lukaCompatible');
  @override
  late final GeneratedColumn<bool> lukaCompatible = GeneratedColumn<bool>(
      'luka_compatible', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("luka_compatible" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _lukaFixtureIdMeta =
      const VerificationMeta('lukaFixtureId');
  @override
  late final GeneratedColumn<String> lukaFixtureId = GeneratedColumn<String>(
      'luka_fixture_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _externalMappingJsonMeta =
      const VerificationMeta('externalMappingJson');
  @override
  late final GeneratedColumn<String> externalMappingJson =
      GeneratedColumn<String>('external_mapping_json', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
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
        sortOrder
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'camera_plan_elements';
  @override
  VerificationContext validateIntegrity(Insertable<CameraPlanElement> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('shot_id')) {
      context.handle(_shotIdMeta,
          shotId.isAcceptableOrUnknown(data['shot_id']!, _shotIdMeta));
    } else if (isInserting) {
      context.missing(_shotIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
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
      context.handle(_rotationMeta,
          rotation.isAcceptableOrUnknown(data['rotation']!, _rotationMeta));
    }
    if (data.containsKey('label')) {
      context.handle(
          _labelMeta, label.isAcceptableOrUnknown(data['label']!, _labelMeta));
    }
    if (data.containsKey('color')) {
      context.handle(
          _colorMeta, color.isAcceptableOrUnknown(data['color']!, _colorMeta));
    }
    if (data.containsKey('camera_stabilization')) {
      context.handle(
          _cameraStabilizationMeta,
          cameraStabilization.isAcceptableOrUnknown(
              data['camera_stabilization']!, _cameraStabilizationMeta));
    }
    if (data.containsKey('camera_lens')) {
      context.handle(
          _cameraLensMeta,
          cameraLens.isAcceptableOrUnknown(
              data['camera_lens']!, _cameraLensMeta));
    }
    if (data.containsKey('camera_letter')) {
      context.handle(
          _cameraLetterMeta,
          cameraLetter.isAcceptableOrUnknown(
              data['camera_letter']!, _cameraLetterMeta));
    }
    if (data.containsKey('camera_number')) {
      context.handle(
          _cameraNumberMeta,
          cameraNumber.isAcceptableOrUnknown(
              data['camera_number']!, _cameraNumberMeta));
    }
    if (data.containsKey('light_type')) {
      context.handle(_lightTypeMeta,
          lightType.isAcceptableOrUnknown(data['light_type']!, _lightTypeMeta));
    }
    if (data.containsKey('luka_compatible')) {
      context.handle(
          _lukaCompatibleMeta,
          lukaCompatible.isAcceptableOrUnknown(
              data['luka_compatible']!, _lukaCompatibleMeta));
    }
    if (data.containsKey('luka_fixture_id')) {
      context.handle(
          _lukaFixtureIdMeta,
          lukaFixtureId.isAcceptableOrUnknown(
              data['luka_fixture_id']!, _lukaFixtureIdMeta));
    }
    if (data.containsKey('external_mapping_json')) {
      context.handle(
          _externalMappingJsonMeta,
          externalMappingJson.isAcceptableOrUnknown(
              data['external_mapping_json']!, _externalMappingJsonMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CameraPlanElement map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CameraPlanElement(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      shotId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}shot_id'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      x: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}x'])!,
      y: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}y'])!,
      rotation: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}rotation'])!,
      label: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}label']),
      color: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}color']),
      cameraStabilization: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}camera_stabilization']),
      cameraLens: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}camera_lens']),
      cameraLetter: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}camera_letter'])!,
      cameraNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}camera_number'])!,
      lightType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}light_type']),
      lukaCompatible: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}luka_compatible'])!,
      lukaFixtureId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}luka_fixture_id']),
      externalMappingJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}external_mapping_json']),
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
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
  const CameraPlanElement(
      {required this.id,
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
      required this.sortOrder});
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
      label:
          label == null && nullToAbsent ? const Value.absent() : Value(label),
      color:
          color == null && nullToAbsent ? const Value.absent() : Value(color),
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

  factory CameraPlanElement.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
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
      cameraStabilization:
          serializer.fromJson<String?>(json['cameraStabilization']),
      cameraLens: serializer.fromJson<String?>(json['cameraLens']),
      cameraLetter: serializer.fromJson<String>(json['cameraLetter']),
      cameraNumber: serializer.fromJson<int>(json['cameraNumber']),
      lightType: serializer.fromJson<String?>(json['lightType']),
      lukaCompatible: serializer.fromJson<bool>(json['lukaCompatible']),
      lukaFixtureId: serializer.fromJson<String?>(json['lukaFixtureId']),
      externalMappingJson:
          serializer.fromJson<String?>(json['externalMappingJson']),
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

  CameraPlanElement copyWith(
          {int? id,
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
          int? sortOrder}) =>
      CameraPlanElement(
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
        lukaFixtureId:
            lukaFixtureId.present ? lukaFixtureId.value : this.lukaFixtureId,
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
      cameraLens:
          data.cameraLens.present ? data.cameraLens.value : this.cameraLens,
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
      sortOrder);
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
  })  : shotId = Value(shotId),
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

  CameraPlanElementsCompanion copyWith(
      {Value<int>? id,
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
      Value<int>? sortOrder}) {
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
      map['external_mapping_json'] =
          Variable<String>(externalMappingJson.value);
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
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _elementIdMeta =
      const VerificationMeta('elementId');
  @override
  late final GeneratedColumn<int> elementId = GeneratedColumn<int>(
      'element_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES camera_plan_elements (id)'));
  static const VerificationMeta _pointNumberMeta =
      const VerificationMeta('pointNumber');
  @override
  late final GeneratedColumn<int> pointNumber = GeneratedColumn<int>(
      'point_number', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _xMeta = const VerificationMeta('x');
  @override
  late final GeneratedColumn<double> x = GeneratedColumn<double>(
      'x', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _yMeta = const VerificationMeta('y');
  @override
  late final GeneratedColumn<double> y = GeneratedColumn<double>(
      'y', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, elementId, pointNumber, x, y];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'camera_path_points';
  @override
  VerificationContext validateIntegrity(Insertable<CameraPathPoint> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('element_id')) {
      context.handle(_elementIdMeta,
          elementId.isAcceptableOrUnknown(data['element_id']!, _elementIdMeta));
    } else if (isInserting) {
      context.missing(_elementIdMeta);
    }
    if (data.containsKey('point_number')) {
      context.handle(
          _pointNumberMeta,
          pointNumber.isAcceptableOrUnknown(
              data['point_number']!, _pointNumberMeta));
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
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      elementId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}element_id'])!,
      pointNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}point_number'])!,
      x: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}x'])!,
      y: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}y'])!,
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
  const CameraPathPoint(
      {required this.id,
      required this.elementId,
      required this.pointNumber,
      required this.x,
      required this.y});
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

  factory CameraPathPoint.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
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

  CameraPathPoint copyWith(
          {int? id, int? elementId, int? pointNumber, double? x, double? y}) =>
      CameraPathPoint(
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
      pointNumber:
          data.pointNumber.present ? data.pointNumber.value : this.pointNumber,
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
  })  : elementId = Value(elementId),
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

  CameraPathPointsCompanion copyWith(
      {Value<int>? id,
      Value<int>? elementId,
      Value<int>? pointNumber,
      Value<double>? x,
      Value<double>? y}) {
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
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _locationIdMeta =
      const VerificationMeta('locationId');
  @override
  late final GeneratedColumn<int> locationId = GeneratedColumn<int>(
      'location_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES location_base_plans (id)'));
  static const VerificationMeta _imagePathMeta =
      const VerificationMeta('imagePath');
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
      'image_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _captionMeta =
      const VerificationMeta('caption');
  @override
  late final GeneratedColumn<String> caption = GeneratedColumn<String>(
      'caption', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('reference'));
  static const VerificationMeta _timeOfDayMeta =
      const VerificationMeta('timeOfDay');
  @override
  late final GeneratedColumn<String> timeOfDay = GeneratedColumn<String>(
      'time_of_day', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns =>
      [id, locationId, imagePath, caption, kind, timeOfDay, sortOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'location_images';
  @override
  VerificationContext validateIntegrity(Insertable<LocationImage> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('location_id')) {
      context.handle(
          _locationIdMeta,
          locationId.isAcceptableOrUnknown(
              data['location_id']!, _locationIdMeta));
    } else if (isInserting) {
      context.missing(_locationIdMeta);
    }
    if (data.containsKey('image_path')) {
      context.handle(_imagePathMeta,
          imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta));
    } else if (isInserting) {
      context.missing(_imagePathMeta);
    }
    if (data.containsKey('caption')) {
      context.handle(_captionMeta,
          caption.isAcceptableOrUnknown(data['caption']!, _captionMeta));
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    }
    if (data.containsKey('time_of_day')) {
      context.handle(
          _timeOfDayMeta,
          timeOfDay.isAcceptableOrUnknown(
              data['time_of_day']!, _timeOfDayMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocationImage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocationImage(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      locationId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}location_id'])!,
      imagePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_path'])!,
      caption: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}caption']),
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      timeOfDay: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}time_of_day']),
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
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
  const LocationImage(
      {required this.id,
      required this.locationId,
      required this.imagePath,
      this.caption,
      required this.kind,
      this.timeOfDay,
      required this.sortOrder});
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

  factory LocationImage.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
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

  LocationImage copyWith(
          {int? id,
          int? locationId,
          String? imagePath,
          Value<String?> caption = const Value.absent(),
          String? kind,
          Value<String?> timeOfDay = const Value.absent(),
          int? sortOrder}) =>
      LocationImage(
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
      locationId:
          data.locationId.present ? data.locationId.value : this.locationId,
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
      id, locationId, imagePath, caption, kind, timeOfDay, sortOrder);
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
  })  : locationId = Value(locationId),
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

  LocationImagesCompanion copyWith(
      {Value<int>? id,
      Value<int>? locationId,
      Value<String>? imagePath,
      Value<String?>? caption,
      Value<String>? kind,
      Value<String?>? timeOfDay,
      Value<int>? sortOrder}) {
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
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _siteIdMeta = const VerificationMeta('siteId');
  @override
  late final GeneratedColumn<int> siteId = GeneratedColumn<int>(
      'site_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES location_sites (id)'));
  static const VerificationMeta _imagePathMeta =
      const VerificationMeta('imagePath');
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
      'image_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _captionMeta =
      const VerificationMeta('caption');
  @override
  late final GeneratedColumn<String> caption = GeneratedColumn<String>(
      'caption', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('reference'));
  static const VerificationMeta _timeOfDayMeta =
      const VerificationMeta('timeOfDay');
  @override
  late final GeneratedColumn<String> timeOfDay = GeneratedColumn<String>(
      'time_of_day', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns =>
      [id, siteId, imagePath, caption, kind, timeOfDay, sortOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'site_images';
  @override
  VerificationContext validateIntegrity(Insertable<SiteImage> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('site_id')) {
      context.handle(_siteIdMeta,
          siteId.isAcceptableOrUnknown(data['site_id']!, _siteIdMeta));
    } else if (isInserting) {
      context.missing(_siteIdMeta);
    }
    if (data.containsKey('image_path')) {
      context.handle(_imagePathMeta,
          imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta));
    } else if (isInserting) {
      context.missing(_imagePathMeta);
    }
    if (data.containsKey('caption')) {
      context.handle(_captionMeta,
          caption.isAcceptableOrUnknown(data['caption']!, _captionMeta));
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    }
    if (data.containsKey('time_of_day')) {
      context.handle(
          _timeOfDayMeta,
          timeOfDay.isAcceptableOrUnknown(
              data['time_of_day']!, _timeOfDayMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SiteImage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SiteImage(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      siteId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}site_id'])!,
      imagePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_path'])!,
      caption: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}caption']),
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      timeOfDay: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}time_of_day']),
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
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
  const SiteImage(
      {required this.id,
      required this.siteId,
      required this.imagePath,
      this.caption,
      required this.kind,
      this.timeOfDay,
      required this.sortOrder});
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

  factory SiteImage.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
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

  SiteImage copyWith(
          {int? id,
          int? siteId,
          String? imagePath,
          Value<String?> caption = const Value.absent(),
          String? kind,
          Value<String?> timeOfDay = const Value.absent(),
          int? sortOrder}) =>
      SiteImage(
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
  })  : siteId = Value(siteId),
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

  SiteImagesCompanion copyWith(
      {Value<int>? id,
      Value<int>? siteId,
      Value<String>? imagePath,
      Value<String?>? caption,
      Value<String>? kind,
      Value<String?>? timeOfDay,
      Value<int>? sortOrder}) {
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
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _brandMeta = const VerificationMeta('brand');
  @override
  late final GeneratedColumn<String> brand = GeneratedColumn<String>(
      'brand', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
      'model', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sensorWidthMmMeta =
      const VerificationMeta('sensorWidthMm');
  @override
  late final GeneratedColumn<double> sensorWidthMm = GeneratedColumn<double>(
      'sensor_width_mm', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _sensorHeightMmMeta =
      const VerificationMeta('sensorHeightMm');
  @override
  late final GeneratedColumn<double> sensorHeightMm = GeneratedColumn<double>(
      'sensor_height_mm', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _recordingFormatsMeta =
      const VerificationMeta('recordingFormats');
  @override
  late final GeneratedColumn<String> recordingFormats = GeneratedColumn<String>(
      'recording_formats', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        brand,
        model,
        sensorWidthMm,
        sensorHeightMm,
        recordingFormats,
        notes
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cameras';
  @override
  VerificationContext validateIntegrity(Insertable<Camera> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('brand')) {
      context.handle(
          _brandMeta, brand.isAcceptableOrUnknown(data['brand']!, _brandMeta));
    } else if (isInserting) {
      context.missing(_brandMeta);
    }
    if (data.containsKey('model')) {
      context.handle(
          _modelMeta, model.isAcceptableOrUnknown(data['model']!, _modelMeta));
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('sensor_width_mm')) {
      context.handle(
          _sensorWidthMmMeta,
          sensorWidthMm.isAcceptableOrUnknown(
              data['sensor_width_mm']!, _sensorWidthMmMeta));
    } else if (isInserting) {
      context.missing(_sensorWidthMmMeta);
    }
    if (data.containsKey('sensor_height_mm')) {
      context.handle(
          _sensorHeightMmMeta,
          sensorHeightMm.isAcceptableOrUnknown(
              data['sensor_height_mm']!, _sensorHeightMmMeta));
    } else if (isInserting) {
      context.missing(_sensorHeightMmMeta);
    }
    if (data.containsKey('recording_formats')) {
      context.handle(
          _recordingFormatsMeta,
          recordingFormats.isAcceptableOrUnknown(
              data['recording_formats']!, _recordingFormatsMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Camera map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Camera(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      brand: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}brand'])!,
      model: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}model'])!,
      sensorWidthMm: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}sensor_width_mm'])!,
      sensorHeightMm: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}sensor_height_mm'])!,
      recordingFormats: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}recording_formats']),
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
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
  const Camera(
      {required this.id,
      required this.brand,
      required this.model,
      required this.sensorWidthMm,
      required this.sensorHeightMm,
      this.recordingFormats,
      this.notes});
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
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
    );
  }

  factory Camera.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
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

  Camera copyWith(
          {int? id,
          String? brand,
          String? model,
          double? sensorWidthMm,
          double? sensorHeightMm,
          Value<String?> recordingFormats = const Value.absent(),
          Value<String?> notes = const Value.absent()}) =>
      Camera(
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
      id, brand, model, sensorWidthMm, sensorHeightMm, recordingFormats, notes);
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
  })  : brand = Value(brand),
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

  CamerasCompanion copyWith(
      {Value<int>? id,
      Value<String>? brand,
      Value<String>? model,
      Value<double>? sensorWidthMm,
      Value<double>? sensorHeightMm,
      Value<String?>? recordingFormats,
      Value<String?>? notes}) {
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
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _brandMeta = const VerificationMeta('brand');
  @override
  late final GeneratedColumn<String> brand = GeneratedColumn<String>(
      'brand', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
      'model', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _focalLengthMeta =
      const VerificationMeta('focalLength');
  @override
  late final GeneratedColumn<double> focalLength = GeneratedColumn<double>(
      'focal_length', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _focalMinMeta =
      const VerificationMeta('focalMin');
  @override
  late final GeneratedColumn<double> focalMin = GeneratedColumn<double>(
      'focal_min', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _focalMaxMeta =
      const VerificationMeta('focalMax');
  @override
  late final GeneratedColumn<double> focalMax = GeneratedColumn<double>(
      'focal_max', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _minTStopMeta =
      const VerificationMeta('minTStop');
  @override
  late final GeneratedColumn<double> minTStop = GeneratedColumn<double>(
      'min_t_stop', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _formatCoverageMeta =
      const VerificationMeta('formatCoverage');
  @override
  late final GeneratedColumn<String> formatCoverage = GeneratedColumn<String>(
      'format_coverage', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
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
        notes
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lenses';
  @override
  VerificationContext validateIntegrity(Insertable<Lense> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('brand')) {
      context.handle(
          _brandMeta, brand.isAcceptableOrUnknown(data['brand']!, _brandMeta));
    } else if (isInserting) {
      context.missing(_brandMeta);
    }
    if (data.containsKey('model')) {
      context.handle(
          _modelMeta, model.isAcceptableOrUnknown(data['model']!, _modelMeta));
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('focal_length')) {
      context.handle(
          _focalLengthMeta,
          focalLength.isAcceptableOrUnknown(
              data['focal_length']!, _focalLengthMeta));
    } else if (isInserting) {
      context.missing(_focalLengthMeta);
    }
    if (data.containsKey('focal_min')) {
      context.handle(_focalMinMeta,
          focalMin.isAcceptableOrUnknown(data['focal_min']!, _focalMinMeta));
    }
    if (data.containsKey('focal_max')) {
      context.handle(_focalMaxMeta,
          focalMax.isAcceptableOrUnknown(data['focal_max']!, _focalMaxMeta));
    }
    if (data.containsKey('min_t_stop')) {
      context.handle(_minTStopMeta,
          minTStop.isAcceptableOrUnknown(data['min_t_stop']!, _minTStopMeta));
    } else if (isInserting) {
      context.missing(_minTStopMeta);
    }
    if (data.containsKey('format_coverage')) {
      context.handle(
          _formatCoverageMeta,
          formatCoverage.isAcceptableOrUnknown(
              data['format_coverage']!, _formatCoverageMeta));
    } else if (isInserting) {
      context.missing(_formatCoverageMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Lense map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Lense(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      brand: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}brand'])!,
      model: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}model'])!,
      focalLength: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}focal_length'])!,
      focalMin: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}focal_min']),
      focalMax: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}focal_max']),
      minTStop: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}min_t_stop'])!,
      formatCoverage: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}format_coverage'])!,
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
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
  const Lense(
      {required this.id,
      required this.brand,
      required this.model,
      required this.focalLength,
      this.focalMin,
      this.focalMax,
      required this.minTStop,
      required this.formatCoverage,
      this.notes});
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
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
    );
  }

  factory Lense.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
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

  Lense copyWith(
          {int? id,
          String? brand,
          String? model,
          double? focalLength,
          Value<double?> focalMin = const Value.absent(),
          Value<double?> focalMax = const Value.absent(),
          double? minTStop,
          String? formatCoverage,
          Value<String?> notes = const Value.absent()}) =>
      Lense(
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
      focalLength:
          data.focalLength.present ? data.focalLength.value : this.focalLength,
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
  int get hashCode => Object.hash(id, brand, model, focalLength, focalMin,
      focalMax, minTStop, formatCoverage, notes);
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
  })  : brand = Value(brand),
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

  LensesCompanion copyWith(
      {Value<int>? id,
      Value<String>? brand,
      Value<String>? model,
      Value<double>? focalLength,
      Value<double?>? focalMin,
      Value<double?>? focalMax,
      Value<double>? minTStop,
      Value<String>? formatCoverage,
      Value<String?>? notes}) {
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
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _brandMeta = const VerificationMeta('brand');
  @override
  late final GeneratedColumn<String> brand = GeneratedColumn<String>(
      'brand', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
      'model', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lightTypeMeta =
      const VerificationMeta('lightType');
  @override
  late final GeneratedColumn<String> lightType = GeneratedColumn<String>(
      'light_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _powerWMeta = const VerificationMeta('powerW');
  @override
  late final GeneratedColumn<int> powerW = GeneratedColumn<int>(
      'power_w', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _colorTempMinMeta =
      const VerificationMeta('colorTempMin');
  @override
  late final GeneratedColumn<int> colorTempMin = GeneratedColumn<int>(
      'color_temp_min', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _colorTempMaxMeta =
      const VerificationMeta('colorTempMax');
  @override
  late final GeneratedColumn<int> colorTempMax = GeneratedColumn<int>(
      'color_temp_max', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _isLukaCompatibleMeta =
      const VerificationMeta('isLukaCompatible');
  @override
  late final GeneratedColumn<bool> isLukaCompatible = GeneratedColumn<bool>(
      'is_luka_compatible', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_luka_compatible" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _lukaFixtureIdMeta =
      const VerificationMeta('lukaFixtureId');
  @override
  late final GeneratedColumn<String> lukaFixtureId = GeneratedColumn<String>(
      'luka_fixture_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
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
        notes
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lights';
  @override
  VerificationContext validateIntegrity(Insertable<Light> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('brand')) {
      context.handle(
          _brandMeta, brand.isAcceptableOrUnknown(data['brand']!, _brandMeta));
    } else if (isInserting) {
      context.missing(_brandMeta);
    }
    if (data.containsKey('model')) {
      context.handle(
          _modelMeta, model.isAcceptableOrUnknown(data['model']!, _modelMeta));
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('light_type')) {
      context.handle(_lightTypeMeta,
          lightType.isAcceptableOrUnknown(data['light_type']!, _lightTypeMeta));
    } else if (isInserting) {
      context.missing(_lightTypeMeta);
    }
    if (data.containsKey('power_w')) {
      context.handle(_powerWMeta,
          powerW.isAcceptableOrUnknown(data['power_w']!, _powerWMeta));
    } else if (isInserting) {
      context.missing(_powerWMeta);
    }
    if (data.containsKey('color_temp_min')) {
      context.handle(
          _colorTempMinMeta,
          colorTempMin.isAcceptableOrUnknown(
              data['color_temp_min']!, _colorTempMinMeta));
    } else if (isInserting) {
      context.missing(_colorTempMinMeta);
    }
    if (data.containsKey('color_temp_max')) {
      context.handle(
          _colorTempMaxMeta,
          colorTempMax.isAcceptableOrUnknown(
              data['color_temp_max']!, _colorTempMaxMeta));
    } else if (isInserting) {
      context.missing(_colorTempMaxMeta);
    }
    if (data.containsKey('is_luka_compatible')) {
      context.handle(
          _isLukaCompatibleMeta,
          isLukaCompatible.isAcceptableOrUnknown(
              data['is_luka_compatible']!, _isLukaCompatibleMeta));
    }
    if (data.containsKey('luka_fixture_id')) {
      context.handle(
          _lukaFixtureIdMeta,
          lukaFixtureId.isAcceptableOrUnknown(
              data['luka_fixture_id']!, _lukaFixtureIdMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Light map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Light(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      brand: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}brand'])!,
      model: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}model'])!,
      lightType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}light_type'])!,
      powerW: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}power_w'])!,
      colorTempMin: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}color_temp_min'])!,
      colorTempMax: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}color_temp_max'])!,
      isLukaCompatible: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}is_luka_compatible'])!,
      lukaFixtureId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}luka_fixture_id']),
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
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
  const Light(
      {required this.id,
      required this.brand,
      required this.model,
      required this.lightType,
      required this.powerW,
      required this.colorTempMin,
      required this.colorTempMax,
      required this.isLukaCompatible,
      this.lukaFixtureId,
      this.notes});
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
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
    );
  }

  factory Light.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
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

  Light copyWith(
          {int? id,
          String? brand,
          String? model,
          String? lightType,
          int? powerW,
          int? colorTempMin,
          int? colorTempMax,
          bool? isLukaCompatible,
          Value<String?> lukaFixtureId = const Value.absent(),
          Value<String?> notes = const Value.absent()}) =>
      Light(
        id: id ?? this.id,
        brand: brand ?? this.brand,
        model: model ?? this.model,
        lightType: lightType ?? this.lightType,
        powerW: powerW ?? this.powerW,
        colorTempMin: colorTempMin ?? this.colorTempMin,
        colorTempMax: colorTempMax ?? this.colorTempMax,
        isLukaCompatible: isLukaCompatible ?? this.isLukaCompatible,
        lukaFixtureId:
            lukaFixtureId.present ? lukaFixtureId.value : this.lukaFixtureId,
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
  int get hashCode => Object.hash(id, brand, model, lightType, powerW,
      colorTempMin, colorTempMax, isLukaCompatible, lukaFixtureId, notes);
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
  })  : brand = Value(brand),
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

  LightsCompanion copyWith(
      {Value<int>? id,
      Value<String>? brand,
      Value<String>? model,
      Value<String>? lightType,
      Value<int>? powerW,
      Value<int>? colorTempMin,
      Value<int>? colorTempMax,
      Value<bool>? isLukaCompatible,
      Value<String?>? lukaFixtureId,
      Value<String?>? notes}) {
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
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _projectIdMeta =
      const VerificationMeta('projectId');
  @override
  late final GeneratedColumn<int> projectId = GeneratedColumn<int>(
      'project_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES projects (id)'));
  static const VerificationMeta _equipmentTypeMeta =
      const VerificationMeta('equipmentType');
  @override
  late final GeneratedColumn<String> equipmentType = GeneratedColumn<String>(
      'equipment_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _equipmentIdMeta =
      const VerificationMeta('equipmentId');
  @override
  late final GeneratedColumn<int> equipmentId = GeneratedColumn<int>(
      'equipment_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('rental'));
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('available'));
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, projectId, equipmentType, equipmentId, source, status, notes];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'project_equipment';
  @override
  VerificationContext validateIntegrity(
      Insertable<ProjectEquipmentData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('project_id')) {
      context.handle(_projectIdMeta,
          projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta));
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('equipment_type')) {
      context.handle(
          _equipmentTypeMeta,
          equipmentType.isAcceptableOrUnknown(
              data['equipment_type']!, _equipmentTypeMeta));
    } else if (isInserting) {
      context.missing(_equipmentTypeMeta);
    }
    if (data.containsKey('equipment_id')) {
      context.handle(
          _equipmentIdMeta,
          equipmentId.isAcceptableOrUnknown(
              data['equipment_id']!, _equipmentIdMeta));
    } else if (isInserting) {
      context.missing(_equipmentIdMeta);
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProjectEquipmentData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProjectEquipmentData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      projectId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}project_id'])!,
      equipmentType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}equipment_type'])!,
      equipmentId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}equipment_id'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
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
  const ProjectEquipmentData(
      {required this.id,
      required this.projectId,
      required this.equipmentType,
      required this.equipmentId,
      required this.source,
      required this.status,
      this.notes});
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
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
    );
  }

  factory ProjectEquipmentData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
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

  ProjectEquipmentData copyWith(
          {int? id,
          int? projectId,
          String? equipmentType,
          int? equipmentId,
          String? source,
          String? status,
          Value<String?> notes = const Value.absent()}) =>
      ProjectEquipmentData(
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
      equipmentId:
          data.equipmentId.present ? data.equipmentId.value : this.equipmentId,
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
      id, projectId, equipmentType, equipmentId, source, status, notes);
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
  })  : projectId = Value(projectId),
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

  ProjectEquipmentCompanion copyWith(
      {Value<int>? id,
      Value<int>? projectId,
      Value<String>? equipmentType,
      Value<int>? equipmentId,
      Value<String>? source,
      Value<String>? status,
      Value<String?>? notes}) {
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
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _projectIdMeta =
      const VerificationMeta('projectId');
  @override
  late final GeneratedColumn<int> projectId = GeneratedColumn<int>(
      'project_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES projects (id)'));
  static const VerificationMeta _visualConceptMeta =
      const VerificationMeta('visualConcept');
  @override
  late final GeneratedColumn<String> visualConcept = GeneratedColumn<String>(
      'visual_concept', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _colorPaletteMeta =
      const VerificationMeta('colorPalette');
  @override
  late final GeneratedColumn<String> colorPalette = GeneratedColumn<String>(
      'color_palette', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lutNameMeta =
      const VerificationMeta('lutName');
  @override
  late final GeneratedColumn<String> lutName = GeneratedColumn<String>(
      'lut_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _filmReferencesMeta =
      const VerificationMeta('filmReferences');
  @override
  late final GeneratedColumn<String> filmReferences = GeneratedColumn<String>(
      'film_references', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lightingPhilosophyMeta =
      const VerificationMeta('lightingPhilosophy');
  @override
  late final GeneratedColumn<String> lightingPhilosophy =
      GeneratedColumn<String>('lighting_philosophy', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _contrastStyleMeta =
      const VerificationMeta('contrastStyle');
  @override
  late final GeneratedColumn<String> contrastStyle = GeneratedColumn<String>(
      'contrast_style', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _actOneNotesMeta =
      const VerificationMeta('actOneNotes');
  @override
  late final GeneratedColumn<String> actOneNotes = GeneratedColumn<String>(
      'act_one_notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _actTwoNotesMeta =
      const VerificationMeta('actTwoNotes');
  @override
  late final GeneratedColumn<String> actTwoNotes = GeneratedColumn<String>(
      'act_two_notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _actThreeNotesMeta =
      const VerificationMeta('actThreeNotes');
  @override
  late final GeneratedColumn<String> actThreeNotes = GeneratedColumn<String>(
      'act_three_notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _moodboardImagesMeta =
      const VerificationMeta('moodboardImages');
  @override
  late final GeneratedColumn<String> moodboardImages = GeneratedColumn<String>(
      'moodboard_images', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
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
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'look_bibles';
  @override
  VerificationContext validateIntegrity(Insertable<LookBible> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('project_id')) {
      context.handle(_projectIdMeta,
          projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta));
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('visual_concept')) {
      context.handle(
          _visualConceptMeta,
          visualConcept.isAcceptableOrUnknown(
              data['visual_concept']!, _visualConceptMeta));
    }
    if (data.containsKey('color_palette')) {
      context.handle(
          _colorPaletteMeta,
          colorPalette.isAcceptableOrUnknown(
              data['color_palette']!, _colorPaletteMeta));
    }
    if (data.containsKey('lut_name')) {
      context.handle(_lutNameMeta,
          lutName.isAcceptableOrUnknown(data['lut_name']!, _lutNameMeta));
    }
    if (data.containsKey('film_references')) {
      context.handle(
          _filmReferencesMeta,
          filmReferences.isAcceptableOrUnknown(
              data['film_references']!, _filmReferencesMeta));
    }
    if (data.containsKey('lighting_philosophy')) {
      context.handle(
          _lightingPhilosophyMeta,
          lightingPhilosophy.isAcceptableOrUnknown(
              data['lighting_philosophy']!, _lightingPhilosophyMeta));
    }
    if (data.containsKey('contrast_style')) {
      context.handle(
          _contrastStyleMeta,
          contrastStyle.isAcceptableOrUnknown(
              data['contrast_style']!, _contrastStyleMeta));
    }
    if (data.containsKey('act_one_notes')) {
      context.handle(
          _actOneNotesMeta,
          actOneNotes.isAcceptableOrUnknown(
              data['act_one_notes']!, _actOneNotesMeta));
    }
    if (data.containsKey('act_two_notes')) {
      context.handle(
          _actTwoNotesMeta,
          actTwoNotes.isAcceptableOrUnknown(
              data['act_two_notes']!, _actTwoNotesMeta));
    }
    if (data.containsKey('act_three_notes')) {
      context.handle(
          _actThreeNotesMeta,
          actThreeNotes.isAcceptableOrUnknown(
              data['act_three_notes']!, _actThreeNotesMeta));
    }
    if (data.containsKey('moodboard_images')) {
      context.handle(
          _moodboardImagesMeta,
          moodboardImages.isAcceptableOrUnknown(
              data['moodboard_images']!, _moodboardImagesMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LookBible map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LookBible(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      projectId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}project_id'])!,
      visualConcept: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}visual_concept']),
      colorPalette: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}color_palette']),
      lutName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}lut_name']),
      filmReferences: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}film_references']),
      lightingPhilosophy: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}lighting_philosophy']),
      contrastStyle: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}contrast_style']),
      actOneNotes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}act_one_notes']),
      actTwoNotes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}act_two_notes']),
      actThreeNotes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}act_three_notes']),
      moodboardImages: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}moodboard_images']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
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
  const LookBible(
      {required this.id,
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
      required this.updatedAt});
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

  factory LookBible.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LookBible(
      id: serializer.fromJson<int>(json['id']),
      projectId: serializer.fromJson<int>(json['projectId']),
      visualConcept: serializer.fromJson<String?>(json['visualConcept']),
      colorPalette: serializer.fromJson<String?>(json['colorPalette']),
      lutName: serializer.fromJson<String?>(json['lutName']),
      filmReferences: serializer.fromJson<String?>(json['filmReferences']),
      lightingPhilosophy:
          serializer.fromJson<String?>(json['lightingPhilosophy']),
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

  LookBible copyWith(
          {int? id,
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
          DateTime? updatedAt}) =>
      LookBible(
        id: id ?? this.id,
        projectId: projectId ?? this.projectId,
        visualConcept:
            visualConcept.present ? visualConcept.value : this.visualConcept,
        colorPalette:
            colorPalette.present ? colorPalette.value : this.colorPalette,
        lutName: lutName.present ? lutName.value : this.lutName,
        filmReferences:
            filmReferences.present ? filmReferences.value : this.filmReferences,
        lightingPhilosophy: lightingPhilosophy.present
            ? lightingPhilosophy.value
            : this.lightingPhilosophy,
        contrastStyle:
            contrastStyle.present ? contrastStyle.value : this.contrastStyle,
        actOneNotes: actOneNotes.present ? actOneNotes.value : this.actOneNotes,
        actTwoNotes: actTwoNotes.present ? actTwoNotes.value : this.actTwoNotes,
        actThreeNotes:
            actThreeNotes.present ? actThreeNotes.value : this.actThreeNotes,
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
      actOneNotes:
          data.actOneNotes.present ? data.actOneNotes.value : this.actOneNotes,
      actTwoNotes:
          data.actTwoNotes.present ? data.actTwoNotes.value : this.actTwoNotes,
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
      updatedAt);
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

  LookBiblesCompanion copyWith(
      {Value<int>? id,
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
      Value<DateTime>? updatedAt}) {
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
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _projectIdMeta =
      const VerificationMeta('projectId');
  @override
  late final GeneratedColumn<int> projectId = GeneratedColumn<int>(
      'project_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES projects (id)'));
  static const VerificationMeta _moduleTypeMeta =
      const VerificationMeta('moduleType');
  @override
  late final GeneratedColumn<String> moduleType = GeneratedColumn<String>(
      'module_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _pdfPathMeta =
      const VerificationMeta('pdfPath');
  @override
  late final GeneratedColumn<String> pdfPath = GeneratedColumn<String>(
      'pdf_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _importedAtMeta =
      const VerificationMeta('importedAt');
  @override
  late final GeneratedColumn<DateTime> importedAt = GeneratedColumn<DateTime>(
      'imported_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, projectId, moduleType, pdfPath, importedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'project_annotated_pdfs';
  @override
  VerificationContext validateIntegrity(
      Insertable<ProjectAnnotatedPdf> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('project_id')) {
      context.handle(_projectIdMeta,
          projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta));
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('module_type')) {
      context.handle(
          _moduleTypeMeta,
          moduleType.isAcceptableOrUnknown(
              data['module_type']!, _moduleTypeMeta));
    } else if (isInserting) {
      context.missing(_moduleTypeMeta);
    }
    if (data.containsKey('pdf_path')) {
      context.handle(_pdfPathMeta,
          pdfPath.isAcceptableOrUnknown(data['pdf_path']!, _pdfPathMeta));
    } else if (isInserting) {
      context.missing(_pdfPathMeta);
    }
    if (data.containsKey('imported_at')) {
      context.handle(
          _importedAtMeta,
          importedAt.isAcceptableOrUnknown(
              data['imported_at']!, _importedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProjectAnnotatedPdf map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProjectAnnotatedPdf(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      projectId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}project_id'])!,
      moduleType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}module_type'])!,
      pdfPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}pdf_path'])!,
      importedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}imported_at'])!,
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
  const ProjectAnnotatedPdf(
      {required this.id,
      required this.projectId,
      required this.moduleType,
      required this.pdfPath,
      required this.importedAt});
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

  factory ProjectAnnotatedPdf.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
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

  ProjectAnnotatedPdf copyWith(
          {int? id,
          int? projectId,
          String? moduleType,
          String? pdfPath,
          DateTime? importedAt}) =>
      ProjectAnnotatedPdf(
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
      moduleType:
          data.moduleType.present ? data.moduleType.value : this.moduleType,
      pdfPath: data.pdfPath.present ? data.pdfPath.value : this.pdfPath,
      importedAt:
          data.importedAt.present ? data.importedAt.value : this.importedAt,
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
  })  : projectId = Value(projectId),
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

  ProjectAnnotatedPdfsCompanion copyWith(
      {Value<int>? id,
      Value<int>? projectId,
      Value<String>? moduleType,
      Value<String>? pdfPath,
      Value<DateTime>? importedAt}) {
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
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _projectIdMeta =
      const VerificationMeta('projectId');
  @override
  late final GeneratedColumn<int> projectId = GeneratedColumn<int>(
      'project_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES projects (id)'));
  static const VerificationMeta _visualConceptMeta =
      const VerificationMeta('visualConcept');
  @override
  late final GeneratedColumn<String> visualConcept = GeneratedColumn<String>(
      'visual_concept', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _narrativeReferencesMeta =
      const VerificationMeta('narrativeReferences');
  @override
  late final GeneratedColumn<String> narrativeReferences =
      GeneratedColumn<String>('narrative_references', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lightingPhilosophyMeta =
      const VerificationMeta('lightingPhilosophy');
  @override
  late final GeneratedColumn<String> lightingPhilosophy =
      GeneratedColumn<String>('lighting_philosophy', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lightQualityMeta =
      const VerificationMeta('lightQuality');
  @override
  late final GeneratedColumn<String> lightQuality = GeneratedColumn<String>(
      'light_quality', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _contrastStyleMeta =
      const VerificationMeta('contrastStyle');
  @override
  late final GeneratedColumn<String> contrastStyle = GeneratedColumn<String>(
      'contrast_style', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _keyFillRatioDayMeta =
      const VerificationMeta('keyFillRatioDay');
  @override
  late final GeneratedColumn<String> keyFillRatioDay = GeneratedColumn<String>(
      'key_fill_ratio_day', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _keyFillRatioNightMeta =
      const VerificationMeta('keyFillRatioNight');
  @override
  late final GeneratedColumn<String> keyFillRatioNight =
      GeneratedColumn<String>('key_fill_ratio_night', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lightSourceMeta =
      const VerificationMeta('lightSource');
  @override
  late final GeneratedColumn<String> lightSource = GeneratedColumn<String>(
      'light_source', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cameraPhilosophyMeta =
      const VerificationMeta('cameraPhilosophy');
  @override
  late final GeneratedColumn<String> cameraPhilosophy = GeneratedColumn<String>(
      'camera_philosophy', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _movementStyleMeta =
      const VerificationMeta('movementStyle');
  @override
  late final GeneratedColumn<String> movementStyle = GeneratedColumn<String>(
      'movement_style', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _preferredMovementsMeta =
      const VerificationMeta('preferredMovements');
  @override
  late final GeneratedColumn<String> preferredMovements =
      GeneratedColumn<String>('preferred_movements', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lensPhilosophyMeta =
      const VerificationMeta('lensPhilosophy');
  @override
  late final GeneratedColumn<String> lensPhilosophy = GeneratedColumn<String>(
      'lens_philosophy', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _opticTypeMeta =
      const VerificationMeta('opticType');
  @override
  late final GeneratedColumn<String> opticType = GeneratedColumn<String>(
      'optic_type', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _primaryFocalLengthsMeta =
      const VerificationMeta('primaryFocalLengths');
  @override
  late final GeneratedColumn<String> primaryFocalLengths =
      GeneratedColumn<String>('primary_focal_lengths', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _primaryLensIdMeta =
      const VerificationMeta('primaryLensId');
  @override
  late final GeneratedColumn<int> primaryLensId = GeneratedColumn<int>(
      'primary_lens_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES lenses (id)'));
  static const VerificationMeta _aspectRatioMeta =
      const VerificationMeta('aspectRatio');
  @override
  late final GeneratedColumn<String> aspectRatio = GeneratedColumn<String>(
      'aspect_ratio', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _aspectRatioJustificationMeta =
      const VerificationMeta('aspectRatioJustification');
  @override
  late final GeneratedColumn<String> aspectRatioJustification =
      GeneratedColumn<String>('aspect_ratio_justification', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _imageTextureMeta =
      const VerificationMeta('imageTexture');
  @override
  late final GeneratedColumn<String> imageTexture = GeneratedColumn<String>(
      'image_texture', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _grainLevelMeta =
      const VerificationMeta('grainLevel');
  @override
  late final GeneratedColumn<String> grainLevel = GeneratedColumn<String>(
      'grain_level', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _highlightBehaviorMeta =
      const VerificationMeta('highlightBehavior');
  @override
  late final GeneratedColumn<String> highlightBehavior =
      GeneratedColumn<String>('highlight_behavior', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _shadowBehaviorMeta =
      const VerificationMeta('shadowBehavior');
  @override
  late final GeneratedColumn<String> shadowBehavior = GeneratedColumn<String>(
      'shadow_behavior', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _workingLutNameMeta =
      const VerificationMeta('workingLutName');
  @override
  late final GeneratedColumn<String> workingLutName = GeneratedColumn<String>(
      'working_lut_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _creativeLutNameMeta =
      const VerificationMeta('creativeLutName');
  @override
  late final GeneratedColumn<String> creativeLutName = GeneratedColumn<String>(
      'creative_lut_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _creativeLutDescriptionMeta =
      const VerificationMeta('creativeLutDescription');
  @override
  late final GeneratedColumn<String> creativeLutDescription =
      GeneratedColumn<String>('creative_lut_description', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
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
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'visual_bibles';
  @override
  VerificationContext validateIntegrity(Insertable<VisualBible> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('project_id')) {
      context.handle(_projectIdMeta,
          projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta));
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('visual_concept')) {
      context.handle(
          _visualConceptMeta,
          visualConcept.isAcceptableOrUnknown(
              data['visual_concept']!, _visualConceptMeta));
    }
    if (data.containsKey('narrative_references')) {
      context.handle(
          _narrativeReferencesMeta,
          narrativeReferences.isAcceptableOrUnknown(
              data['narrative_references']!, _narrativeReferencesMeta));
    }
    if (data.containsKey('lighting_philosophy')) {
      context.handle(
          _lightingPhilosophyMeta,
          lightingPhilosophy.isAcceptableOrUnknown(
              data['lighting_philosophy']!, _lightingPhilosophyMeta));
    }
    if (data.containsKey('light_quality')) {
      context.handle(
          _lightQualityMeta,
          lightQuality.isAcceptableOrUnknown(
              data['light_quality']!, _lightQualityMeta));
    }
    if (data.containsKey('contrast_style')) {
      context.handle(
          _contrastStyleMeta,
          contrastStyle.isAcceptableOrUnknown(
              data['contrast_style']!, _contrastStyleMeta));
    }
    if (data.containsKey('key_fill_ratio_day')) {
      context.handle(
          _keyFillRatioDayMeta,
          keyFillRatioDay.isAcceptableOrUnknown(
              data['key_fill_ratio_day']!, _keyFillRatioDayMeta));
    }
    if (data.containsKey('key_fill_ratio_night')) {
      context.handle(
          _keyFillRatioNightMeta,
          keyFillRatioNight.isAcceptableOrUnknown(
              data['key_fill_ratio_night']!, _keyFillRatioNightMeta));
    }
    if (data.containsKey('light_source')) {
      context.handle(
          _lightSourceMeta,
          lightSource.isAcceptableOrUnknown(
              data['light_source']!, _lightSourceMeta));
    }
    if (data.containsKey('camera_philosophy')) {
      context.handle(
          _cameraPhilosophyMeta,
          cameraPhilosophy.isAcceptableOrUnknown(
              data['camera_philosophy']!, _cameraPhilosophyMeta));
    }
    if (data.containsKey('movement_style')) {
      context.handle(
          _movementStyleMeta,
          movementStyle.isAcceptableOrUnknown(
              data['movement_style']!, _movementStyleMeta));
    }
    if (data.containsKey('preferred_movements')) {
      context.handle(
          _preferredMovementsMeta,
          preferredMovements.isAcceptableOrUnknown(
              data['preferred_movements']!, _preferredMovementsMeta));
    }
    if (data.containsKey('lens_philosophy')) {
      context.handle(
          _lensPhilosophyMeta,
          lensPhilosophy.isAcceptableOrUnknown(
              data['lens_philosophy']!, _lensPhilosophyMeta));
    }
    if (data.containsKey('optic_type')) {
      context.handle(_opticTypeMeta,
          opticType.isAcceptableOrUnknown(data['optic_type']!, _opticTypeMeta));
    }
    if (data.containsKey('primary_focal_lengths')) {
      context.handle(
          _primaryFocalLengthsMeta,
          primaryFocalLengths.isAcceptableOrUnknown(
              data['primary_focal_lengths']!, _primaryFocalLengthsMeta));
    }
    if (data.containsKey('primary_lens_id')) {
      context.handle(
          _primaryLensIdMeta,
          primaryLensId.isAcceptableOrUnknown(
              data['primary_lens_id']!, _primaryLensIdMeta));
    }
    if (data.containsKey('aspect_ratio')) {
      context.handle(
          _aspectRatioMeta,
          aspectRatio.isAcceptableOrUnknown(
              data['aspect_ratio']!, _aspectRatioMeta));
    }
    if (data.containsKey('aspect_ratio_justification')) {
      context.handle(
          _aspectRatioJustificationMeta,
          aspectRatioJustification.isAcceptableOrUnknown(
              data['aspect_ratio_justification']!,
              _aspectRatioJustificationMeta));
    }
    if (data.containsKey('image_texture')) {
      context.handle(
          _imageTextureMeta,
          imageTexture.isAcceptableOrUnknown(
              data['image_texture']!, _imageTextureMeta));
    }
    if (data.containsKey('grain_level')) {
      context.handle(
          _grainLevelMeta,
          grainLevel.isAcceptableOrUnknown(
              data['grain_level']!, _grainLevelMeta));
    }
    if (data.containsKey('highlight_behavior')) {
      context.handle(
          _highlightBehaviorMeta,
          highlightBehavior.isAcceptableOrUnknown(
              data['highlight_behavior']!, _highlightBehaviorMeta));
    }
    if (data.containsKey('shadow_behavior')) {
      context.handle(
          _shadowBehaviorMeta,
          shadowBehavior.isAcceptableOrUnknown(
              data['shadow_behavior']!, _shadowBehaviorMeta));
    }
    if (data.containsKey('working_lut_name')) {
      context.handle(
          _workingLutNameMeta,
          workingLutName.isAcceptableOrUnknown(
              data['working_lut_name']!, _workingLutNameMeta));
    }
    if (data.containsKey('creative_lut_name')) {
      context.handle(
          _creativeLutNameMeta,
          creativeLutName.isAcceptableOrUnknown(
              data['creative_lut_name']!, _creativeLutNameMeta));
    }
    if (data.containsKey('creative_lut_description')) {
      context.handle(
          _creativeLutDescriptionMeta,
          creativeLutDescription.isAcceptableOrUnknown(
              data['creative_lut_description']!, _creativeLutDescriptionMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VisualBible map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VisualBible(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      projectId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}project_id'])!,
      visualConcept: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}visual_concept']),
      narrativeReferences: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}narrative_references']),
      lightingPhilosophy: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}lighting_philosophy']),
      lightQuality: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}light_quality']),
      contrastStyle: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}contrast_style']),
      keyFillRatioDay: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}key_fill_ratio_day']),
      keyFillRatioNight: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}key_fill_ratio_night']),
      lightSource: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}light_source']),
      cameraPhilosophy: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}camera_philosophy']),
      movementStyle: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}movement_style']),
      preferredMovements: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}preferred_movements']),
      lensPhilosophy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}lens_philosophy']),
      opticType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}optic_type']),
      primaryFocalLengths: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}primary_focal_lengths']),
      primaryLensId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}primary_lens_id']),
      aspectRatio: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}aspect_ratio']),
      aspectRatioJustification: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}aspect_ratio_justification']),
      imageTexture: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_texture']),
      grainLevel: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}grain_level']),
      highlightBehavior: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}highlight_behavior']),
      shadowBehavior: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}shadow_behavior']),
      workingLutName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}working_lut_name']),
      creativeLutName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}creative_lut_name']),
      creativeLutDescription: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}creative_lut_description']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
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
  const VisualBible(
      {required this.id,
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
      required this.updatedAt});
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
      map['aspect_ratio_justification'] =
          Variable<String>(aspectRatioJustification);
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
      map['creative_lut_description'] =
          Variable<String>(creativeLutDescription);
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

  factory VisualBible.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VisualBible(
      id: serializer.fromJson<int>(json['id']),
      projectId: serializer.fromJson<int>(json['projectId']),
      visualConcept: serializer.fromJson<String?>(json['visualConcept']),
      narrativeReferences:
          serializer.fromJson<String?>(json['narrativeReferences']),
      lightingPhilosophy:
          serializer.fromJson<String?>(json['lightingPhilosophy']),
      lightQuality: serializer.fromJson<String?>(json['lightQuality']),
      contrastStyle: serializer.fromJson<String?>(json['contrastStyle']),
      keyFillRatioDay: serializer.fromJson<String?>(json['keyFillRatioDay']),
      keyFillRatioNight:
          serializer.fromJson<String?>(json['keyFillRatioNight']),
      lightSource: serializer.fromJson<String?>(json['lightSource']),
      cameraPhilosophy: serializer.fromJson<String?>(json['cameraPhilosophy']),
      movementStyle: serializer.fromJson<String?>(json['movementStyle']),
      preferredMovements:
          serializer.fromJson<String?>(json['preferredMovements']),
      lensPhilosophy: serializer.fromJson<String?>(json['lensPhilosophy']),
      opticType: serializer.fromJson<String?>(json['opticType']),
      primaryFocalLengths:
          serializer.fromJson<String?>(json['primaryFocalLengths']),
      primaryLensId: serializer.fromJson<int?>(json['primaryLensId']),
      aspectRatio: serializer.fromJson<String?>(json['aspectRatio']),
      aspectRatioJustification:
          serializer.fromJson<String?>(json['aspectRatioJustification']),
      imageTexture: serializer.fromJson<String?>(json['imageTexture']),
      grainLevel: serializer.fromJson<String?>(json['grainLevel']),
      highlightBehavior:
          serializer.fromJson<String?>(json['highlightBehavior']),
      shadowBehavior: serializer.fromJson<String?>(json['shadowBehavior']),
      workingLutName: serializer.fromJson<String?>(json['workingLutName']),
      creativeLutName: serializer.fromJson<String?>(json['creativeLutName']),
      creativeLutDescription:
          serializer.fromJson<String?>(json['creativeLutDescription']),
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
      'aspectRatioJustification':
          serializer.toJson<String?>(aspectRatioJustification),
      'imageTexture': serializer.toJson<String?>(imageTexture),
      'grainLevel': serializer.toJson<String?>(grainLevel),
      'highlightBehavior': serializer.toJson<String?>(highlightBehavior),
      'shadowBehavior': serializer.toJson<String?>(shadowBehavior),
      'workingLutName': serializer.toJson<String?>(workingLutName),
      'creativeLutName': serializer.toJson<String?>(creativeLutName),
      'creativeLutDescription':
          serializer.toJson<String?>(creativeLutDescription),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  VisualBible copyWith(
          {int? id,
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
          DateTime? updatedAt}) =>
      VisualBible(
        id: id ?? this.id,
        projectId: projectId ?? this.projectId,
        visualConcept:
            visualConcept.present ? visualConcept.value : this.visualConcept,
        narrativeReferences: narrativeReferences.present
            ? narrativeReferences.value
            : this.narrativeReferences,
        lightingPhilosophy: lightingPhilosophy.present
            ? lightingPhilosophy.value
            : this.lightingPhilosophy,
        lightQuality:
            lightQuality.present ? lightQuality.value : this.lightQuality,
        contrastStyle:
            contrastStyle.present ? contrastStyle.value : this.contrastStyle,
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
        movementStyle:
            movementStyle.present ? movementStyle.value : this.movementStyle,
        preferredMovements: preferredMovements.present
            ? preferredMovements.value
            : this.preferredMovements,
        lensPhilosophy:
            lensPhilosophy.present ? lensPhilosophy.value : this.lensPhilosophy,
        opticType: opticType.present ? opticType.value : this.opticType,
        primaryFocalLengths: primaryFocalLengths.present
            ? primaryFocalLengths.value
            : this.primaryFocalLengths,
        primaryLensId:
            primaryLensId.present ? primaryLensId.value : this.primaryLensId,
        aspectRatio: aspectRatio.present ? aspectRatio.value : this.aspectRatio,
        aspectRatioJustification: aspectRatioJustification.present
            ? aspectRatioJustification.value
            : this.aspectRatioJustification,
        imageTexture:
            imageTexture.present ? imageTexture.value : this.imageTexture,
        grainLevel: grainLevel.present ? grainLevel.value : this.grainLevel,
        highlightBehavior: highlightBehavior.present
            ? highlightBehavior.value
            : this.highlightBehavior,
        shadowBehavior:
            shadowBehavior.present ? shadowBehavior.value : this.shadowBehavior,
        workingLutName:
            workingLutName.present ? workingLutName.value : this.workingLutName,
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
      lightSource:
          data.lightSource.present ? data.lightSource.value : this.lightSource,
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
      aspectRatio:
          data.aspectRatio.present ? data.aspectRatio.value : this.aspectRatio,
      aspectRatioJustification: data.aspectRatioJustification.present
          ? data.aspectRatioJustification.value
          : this.aspectRatioJustification,
      imageTexture: data.imageTexture.present
          ? data.imageTexture.value
          : this.imageTexture,
      grainLevel:
          data.grainLevel.present ? data.grainLevel.value : this.grainLevel,
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
        updatedAt
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

  VisualBiblesCompanion copyWith(
      {Value<int>? id,
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
      Value<DateTime>? updatedAt}) {
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
      map['primary_focal_lengths'] =
          Variable<String>(primaryFocalLengths.value);
    }
    if (primaryLensId.present) {
      map['primary_lens_id'] = Variable<int>(primaryLensId.value);
    }
    if (aspectRatio.present) {
      map['aspect_ratio'] = Variable<String>(aspectRatio.value);
    }
    if (aspectRatioJustification.present) {
      map['aspect_ratio_justification'] =
          Variable<String>(aspectRatioJustification.value);
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
      map['creative_lut_description'] =
          Variable<String>(creativeLutDescription.value);
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
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _bibleIdMeta =
      const VerificationMeta('bibleId');
  @override
  late final GeneratedColumn<int> bibleId = GeneratedColumn<int>(
      'bible_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES visual_bibles (id)'));
  static const VerificationMeta _blockNameMeta =
      const VerificationMeta('blockName');
  @override
  late final GeneratedColumn<String> blockName = GeneratedColumn<String>(
      'block_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _emotionalIntentMeta =
      const VerificationMeta('emotionalIntent');
  @override
  late final GeneratedColumn<String> emotionalIntent = GeneratedColumn<String>(
      'emotional_intent', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _dominantColorsMeta =
      const VerificationMeta('dominantColors');
  @override
  late final GeneratedColumn<String> dominantColors = GeneratedColumn<String>(
      'dominant_colors', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _accentColorsMeta =
      const VerificationMeta('accentColors');
  @override
  late final GeneratedColumn<String> accentColors = GeneratedColumn<String>(
      'accent_colors', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _prohibitedColorsMeta =
      const VerificationMeta('prohibitedColors');
  @override
  late final GeneratedColumn<String> prohibitedColors = GeneratedColumn<String>(
      'prohibited_colors', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _colorTempKelvinMeta =
      const VerificationMeta('colorTempKelvin');
  @override
  late final GeneratedColumn<int> colorTempKelvin = GeneratedColumn<int>(
      'color_temp_kelvin', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _referenceImagesMeta =
      const VerificationMeta('referenceImages');
  @override
  late final GeneratedColumn<String> referenceImages = GeneratedColumn<String>(
      'reference_images', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
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
        sortOrder
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'visual_bible_color_blocks';
  @override
  VerificationContext validateIntegrity(
      Insertable<VisualBibleColorBlock> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('bible_id')) {
      context.handle(_bibleIdMeta,
          bibleId.isAcceptableOrUnknown(data['bible_id']!, _bibleIdMeta));
    } else if (isInserting) {
      context.missing(_bibleIdMeta);
    }
    if (data.containsKey('block_name')) {
      context.handle(_blockNameMeta,
          blockName.isAcceptableOrUnknown(data['block_name']!, _blockNameMeta));
    } else if (isInserting) {
      context.missing(_blockNameMeta);
    }
    if (data.containsKey('emotional_intent')) {
      context.handle(
          _emotionalIntentMeta,
          emotionalIntent.isAcceptableOrUnknown(
              data['emotional_intent']!, _emotionalIntentMeta));
    }
    if (data.containsKey('dominant_colors')) {
      context.handle(
          _dominantColorsMeta,
          dominantColors.isAcceptableOrUnknown(
              data['dominant_colors']!, _dominantColorsMeta));
    } else if (isInserting) {
      context.missing(_dominantColorsMeta);
    }
    if (data.containsKey('accent_colors')) {
      context.handle(
          _accentColorsMeta,
          accentColors.isAcceptableOrUnknown(
              data['accent_colors']!, _accentColorsMeta));
    }
    if (data.containsKey('prohibited_colors')) {
      context.handle(
          _prohibitedColorsMeta,
          prohibitedColors.isAcceptableOrUnknown(
              data['prohibited_colors']!, _prohibitedColorsMeta));
    }
    if (data.containsKey('color_temp_kelvin')) {
      context.handle(
          _colorTempKelvinMeta,
          colorTempKelvin.isAcceptableOrUnknown(
              data['color_temp_kelvin']!, _colorTempKelvinMeta));
    }
    if (data.containsKey('reference_images')) {
      context.handle(
          _referenceImagesMeta,
          referenceImages.isAcceptableOrUnknown(
              data['reference_images']!, _referenceImagesMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VisualBibleColorBlock map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VisualBibleColorBlock(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      bibleId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}bible_id'])!,
      blockName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}block_name'])!,
      emotionalIntent: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}emotional_intent']),
      dominantColors: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}dominant_colors'])!,
      accentColors: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}accent_colors']),
      prohibitedColors: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}prohibited_colors']),
      colorTempKelvin: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}color_temp_kelvin']),
      referenceImages: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}reference_images']),
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
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
  const VisualBibleColorBlock(
      {required this.id,
      required this.bibleId,
      required this.blockName,
      this.emotionalIntent,
      required this.dominantColors,
      this.accentColors,
      this.prohibitedColors,
      this.colorTempKelvin,
      this.referenceImages,
      required this.sortOrder});
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

  factory VisualBibleColorBlock.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
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

  VisualBibleColorBlock copyWith(
          {int? id,
          int? bibleId,
          String? blockName,
          Value<String?> emotionalIntent = const Value.absent(),
          String? dominantColors,
          Value<String?> accentColors = const Value.absent(),
          Value<String?> prohibitedColors = const Value.absent(),
          Value<int?> colorTempKelvin = const Value.absent(),
          Value<String?> referenceImages = const Value.absent(),
          int? sortOrder}) =>
      VisualBibleColorBlock(
        id: id ?? this.id,
        bibleId: bibleId ?? this.bibleId,
        blockName: blockName ?? this.blockName,
        emotionalIntent: emotionalIntent.present
            ? emotionalIntent.value
            : this.emotionalIntent,
        dominantColors: dominantColors ?? this.dominantColors,
        accentColors:
            accentColors.present ? accentColors.value : this.accentColors,
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
      VisualBibleColorBlocksCompanion data) {
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
      sortOrder);
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
  })  : bibleId = Value(bibleId),
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

  VisualBibleColorBlocksCompanion copyWith(
      {Value<int>? id,
      Value<int>? bibleId,
      Value<String>? blockName,
      Value<String?>? emotionalIntent,
      Value<String>? dominantColors,
      Value<String?>? accentColors,
      Value<String?>? prohibitedColors,
      Value<int?>? colorTempKelvin,
      Value<String?>? referenceImages,
      Value<int>? sortOrder}) {
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
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _bibleIdMeta =
      const VerificationMeta('bibleId');
  @override
  late final GeneratedColumn<int> bibleId = GeneratedColumn<int>(
      'bible_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES visual_bibles (id)'));
  static const VerificationMeta _locationNameMeta =
      const VerificationMeta('locationName');
  @override
  late final GeneratedColumn<String> locationName = GeneratedColumn<String>(
      'location_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lightingNoteMeta =
      const VerificationMeta('lightingNote');
  @override
  late final GeneratedColumn<String> lightingNote = GeneratedColumn<String>(
      'lighting_note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _colorNoteMeta =
      const VerificationMeta('colorNote');
  @override
  late final GeneratedColumn<String> colorNote = GeneratedColumn<String>(
      'color_note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _referenceImagesMeta =
      const VerificationMeta('referenceImages');
  @override
  late final GeneratedColumn<String> referenceImages = GeneratedColumn<String>(
      'reference_images', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _linkedShotIdsMeta =
      const VerificationMeta('linkedShotIds');
  @override
  late final GeneratedColumn<String> linkedShotIds = GeneratedColumn<String>(
      'linked_shot_ids', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        bibleId,
        locationName,
        lightingNote,
        colorNote,
        referenceImages,
        linkedShotIds
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'visual_bible_location_refs';
  @override
  VerificationContext validateIntegrity(
      Insertable<VisualBibleLocationRef> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('bible_id')) {
      context.handle(_bibleIdMeta,
          bibleId.isAcceptableOrUnknown(data['bible_id']!, _bibleIdMeta));
    } else if (isInserting) {
      context.missing(_bibleIdMeta);
    }
    if (data.containsKey('location_name')) {
      context.handle(
          _locationNameMeta,
          locationName.isAcceptableOrUnknown(
              data['location_name']!, _locationNameMeta));
    } else if (isInserting) {
      context.missing(_locationNameMeta);
    }
    if (data.containsKey('lighting_note')) {
      context.handle(
          _lightingNoteMeta,
          lightingNote.isAcceptableOrUnknown(
              data['lighting_note']!, _lightingNoteMeta));
    }
    if (data.containsKey('color_note')) {
      context.handle(_colorNoteMeta,
          colorNote.isAcceptableOrUnknown(data['color_note']!, _colorNoteMeta));
    }
    if (data.containsKey('reference_images')) {
      context.handle(
          _referenceImagesMeta,
          referenceImages.isAcceptableOrUnknown(
              data['reference_images']!, _referenceImagesMeta));
    }
    if (data.containsKey('linked_shot_ids')) {
      context.handle(
          _linkedShotIdsMeta,
          linkedShotIds.isAcceptableOrUnknown(
              data['linked_shot_ids']!, _linkedShotIdsMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VisualBibleLocationRef map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VisualBibleLocationRef(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      bibleId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}bible_id'])!,
      locationName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}location_name'])!,
      lightingNote: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}lighting_note']),
      colorNote: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}color_note']),
      referenceImages: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}reference_images']),
      linkedShotIds: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}linked_shot_ids']),
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
  const VisualBibleLocationRef(
      {required this.id,
      required this.bibleId,
      required this.locationName,
      this.lightingNote,
      this.colorNote,
      this.referenceImages,
      this.linkedShotIds});
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

  factory VisualBibleLocationRef.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
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

  VisualBibleLocationRef copyWith(
          {int? id,
          int? bibleId,
          String? locationName,
          Value<String?> lightingNote = const Value.absent(),
          Value<String?> colorNote = const Value.absent(),
          Value<String?> referenceImages = const Value.absent(),
          Value<String?> linkedShotIds = const Value.absent()}) =>
      VisualBibleLocationRef(
        id: id ?? this.id,
        bibleId: bibleId ?? this.bibleId,
        locationName: locationName ?? this.locationName,
        lightingNote:
            lightingNote.present ? lightingNote.value : this.lightingNote,
        colorNote: colorNote.present ? colorNote.value : this.colorNote,
        referenceImages: referenceImages.present
            ? referenceImages.value
            : this.referenceImages,
        linkedShotIds:
            linkedShotIds.present ? linkedShotIds.value : this.linkedShotIds,
      );
  VisualBibleLocationRef copyWithCompanion(
      VisualBibleLocationRefsCompanion data) {
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
  int get hashCode => Object.hash(id, bibleId, locationName, lightingNote,
      colorNote, referenceImages, linkedShotIds);
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
  })  : bibleId = Value(bibleId),
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

  VisualBibleLocationRefsCompanion copyWith(
      {Value<int>? id,
      Value<int>? bibleId,
      Value<String>? locationName,
      Value<String?>? lightingNote,
      Value<String?>? colorNote,
      Value<String?>? referenceImages,
      Value<String?>? linkedShotIds}) {
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
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _projectIdMeta =
      const VerificationMeta('projectId');
  @override
  late final GeneratedColumn<int> projectId = GeneratedColumn<int>(
      'project_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES projects (id)'));
  static const VerificationMeta _bibleIdMeta =
      const VerificationMeta('bibleId');
  @override
  late final GeneratedColumn<int> bibleId = GeneratedColumn<int>(
      'bible_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES visual_bibles (id)'));
  static const VerificationMeta _imagePathMeta =
      const VerificationMeta('imagePath');
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
      'image_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('manual'));
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _captionMeta =
      const VerificationMeta('caption');
  @override
  late final GeneratedColumn<String> caption = GeneratedColumn<String>(
      'caption', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _filmReferenceMeta =
      const VerificationMeta('filmReference');
  @override
  late final GeneratedColumn<String> filmReference = GeneratedColumn<String>(
      'film_reference', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _linkedSceneIdMeta =
      const VerificationMeta('linkedSceneId');
  @override
  late final GeneratedColumn<int> linkedSceneId = GeneratedColumn<int>(
      'linked_scene_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _linkedLocationNameMeta =
      const VerificationMeta('linkedLocationName');
  @override
  late final GeneratedColumn<String> linkedLocationName =
      GeneratedColumn<String>('linked_location_name', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
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
        sortOrder
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'moodboard_images';
  @override
  VerificationContext validateIntegrity(Insertable<MoodboardImage> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('project_id')) {
      context.handle(_projectIdMeta,
          projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta));
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('bible_id')) {
      context.handle(_bibleIdMeta,
          bibleId.isAcceptableOrUnknown(data['bible_id']!, _bibleIdMeta));
    }
    if (data.containsKey('image_path')) {
      context.handle(_imagePathMeta,
          imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta));
    } else if (isInserting) {
      context.missing(_imagePathMeta);
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    }
    if (data.containsKey('caption')) {
      context.handle(_captionMeta,
          caption.isAcceptableOrUnknown(data['caption']!, _captionMeta));
    }
    if (data.containsKey('film_reference')) {
      context.handle(
          _filmReferenceMeta,
          filmReference.isAcceptableOrUnknown(
              data['film_reference']!, _filmReferenceMeta));
    }
    if (data.containsKey('linked_scene_id')) {
      context.handle(
          _linkedSceneIdMeta,
          linkedSceneId.isAcceptableOrUnknown(
              data['linked_scene_id']!, _linkedSceneIdMeta));
    }
    if (data.containsKey('linked_location_name')) {
      context.handle(
          _linkedLocationNameMeta,
          linkedLocationName.isAcceptableOrUnknown(
              data['linked_location_name']!, _linkedLocationNameMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MoodboardImage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MoodboardImage(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      projectId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}project_id'])!,
      bibleId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}bible_id']),
      imagePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_path'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category']),
      caption: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}caption']),
      filmReference: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}film_reference']),
      linkedSceneId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}linked_scene_id']),
      linkedLocationName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}linked_location_name']),
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
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
  const MoodboardImage(
      {required this.id,
      required this.projectId,
      this.bibleId,
      required this.imagePath,
      required this.source,
      this.category,
      this.caption,
      this.filmReference,
      this.linkedSceneId,
      this.linkedLocationName,
      required this.sortOrder});
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

  factory MoodboardImage.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
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
      linkedLocationName:
          serializer.fromJson<String?>(json['linkedLocationName']),
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

  MoodboardImage copyWith(
          {int? id,
          int? projectId,
          Value<int?> bibleId = const Value.absent(),
          String? imagePath,
          String? source,
          Value<String?> category = const Value.absent(),
          Value<String?> caption = const Value.absent(),
          Value<String?> filmReference = const Value.absent(),
          Value<int?> linkedSceneId = const Value.absent(),
          Value<String?> linkedLocationName = const Value.absent(),
          int? sortOrder}) =>
      MoodboardImage(
        id: id ?? this.id,
        projectId: projectId ?? this.projectId,
        bibleId: bibleId.present ? bibleId.value : this.bibleId,
        imagePath: imagePath ?? this.imagePath,
        source: source ?? this.source,
        category: category.present ? category.value : this.category,
        caption: caption.present ? caption.value : this.caption,
        filmReference:
            filmReference.present ? filmReference.value : this.filmReference,
        linkedSceneId:
            linkedSceneId.present ? linkedSceneId.value : this.linkedSceneId,
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
      sortOrder);
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
  })  : projectId = Value(projectId),
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

  MoodboardImagesCompanion copyWith(
      {Value<int>? id,
      Value<int>? projectId,
      Value<int?>? bibleId,
      Value<String>? imagePath,
      Value<String>? source,
      Value<String?>? category,
      Value<String?>? caption,
      Value<String?>? filmReference,
      Value<int?>? linkedSceneId,
      Value<String?>? linkedLocationName,
      Value<int>? sortOrder}) {
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
  late final $CameraPathPointsTable cameraPathPoints =
      $CameraPathPointsTable(this);
  late final $LocationImagesTable locationImages = $LocationImagesTable(this);
  late final $SiteImagesTable siteImages = $SiteImagesTable(this);
  late final $CamerasTable cameras = $CamerasTable(this);
  late final $LensesTable lenses = $LensesTable(this);
  late final $LightsTable lights = $LightsTable(this);
  late final $ProjectEquipmentTable projectEquipment =
      $ProjectEquipmentTable(this);
  late final $LookBiblesTable lookBibles = $LookBiblesTable(this);
  late final $ProjectAnnotatedPdfsTable projectAnnotatedPdfs =
      $ProjectAnnotatedPdfsTable(this);
  late final $VisualBiblesTable visualBibles = $VisualBiblesTable(this);
  late final $VisualBibleColorBlocksTable visualBibleColorBlocks =
      $VisualBibleColorBlocksTable(this);
  late final $VisualBibleLocationRefsTable visualBibleLocationRefs =
      $VisualBibleLocationRefsTable(this);
  late final $MoodboardImagesTable moodboardImages =
      $MoodboardImagesTable(this);
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
        moodboardImages
      ];
}

typedef $$ProjectGroupsTableCreateCompanionBuilder = ProjectGroupsCompanion
    Function({
  Value<int> id,
  required String name,
  Value<int> sortOrder,
});
typedef $$ProjectGroupsTableUpdateCompanionBuilder = ProjectGroupsCompanion
    Function({
  Value<int> id,
  Value<String> name,
  Value<int> sortOrder,
});

class $$ProjectGroupsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ProjectGroupsTable,
    ProjectGroup,
    $$ProjectGroupsTableFilterComposer,
    $$ProjectGroupsTableOrderingComposer,
    $$ProjectGroupsTableCreateCompanionBuilder,
    $$ProjectGroupsTableUpdateCompanionBuilder> {
  $$ProjectGroupsTableTableManager(_$AppDatabase db, $ProjectGroupsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$ProjectGroupsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$ProjectGroupsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
          }) =>
              ProjectGroupsCompanion(
            id: id,
            name: name,
            sortOrder: sortOrder,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            Value<int> sortOrder = const Value.absent(),
          }) =>
              ProjectGroupsCompanion.insert(
            id: id,
            name: name,
            sortOrder: sortOrder,
          ),
        ));
}

class $$ProjectGroupsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $ProjectGroupsTable> {
  $$ProjectGroupsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get sortOrder => $state.composableBuilder(
      column: $state.table.sortOrder,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ComposableFilter projectsRefs(
      ComposableFilter Function($$ProjectsTableFilterComposer f) f) {
    final $$ProjectsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.projects,
        getReferencedColumn: (t) => t.groupId,
        builder: (joinBuilder, parentComposers) =>
            $$ProjectsTableFilterComposer(ComposerState(
                $state.db, $state.db.projects, joinBuilder, parentComposers)));
    return f(composer);
  }
}

class $$ProjectGroupsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $ProjectGroupsTable> {
  $$ProjectGroupsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get sortOrder => $state.composableBuilder(
      column: $state.table.sortOrder,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$ProjectsTableCreateCompanionBuilder = ProjectsCompanion Function({
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
typedef $$ProjectsTableUpdateCompanionBuilder = ProjectsCompanion Function({
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

class $$ProjectsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ProjectsTable,
    Project,
    $$ProjectsTableFilterComposer,
    $$ProjectsTableOrderingComposer,
    $$ProjectsTableCreateCompanionBuilder,
    $$ProjectsTableUpdateCompanionBuilder> {
  $$ProjectsTableTableManager(_$AppDatabase db, $ProjectsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$ProjectsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$ProjectsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
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
          }) =>
              ProjectsCompanion(
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
          createCompanionCallback: ({
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
          }) =>
              ProjectsCompanion.insert(
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
        ));
}

class $$ProjectsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get director => $state.composableBuilder(
      column: $state.table.director,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get description => $state.composableBuilder(
      column: $state.table.description,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get clientName => $state.composableBuilder(
      column: $state.table.clientName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get status => $state.composableBuilder(
      column: $state.table.status,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get iconCode => $state.composableBuilder(
      column: $state.table.iconCode,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get coverImagePath => $state.composableBuilder(
      column: $state.table.coverImagePath,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get shootingStartDate => $state.composableBuilder(
      column: $state.table.shootingStartDate,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get shootingEndDate => $state.composableBuilder(
      column: $state.table.shootingEndDate,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get googleEmail => $state.composableBuilder(
      column: $state.table.googleEmail,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get scriptFilePath => $state.composableBuilder(
      column: $state.table.scriptFilePath,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get scriptFileName => $state.composableBuilder(
      column: $state.table.scriptFileName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get sortOrder => $state.composableBuilder(
      column: $state.table.sortOrder,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get updatedAt => $state.composableBuilder(
      column: $state.table.updatedAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$ProjectGroupsTableFilterComposer get groupId {
    final $$ProjectGroupsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.groupId,
        referencedTable: $state.db.projectGroups,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$ProjectGroupsTableFilterComposer(ComposerState($state.db,
                $state.db.projectGroups, joinBuilder, parentComposers)));
    return composer;
  }

  ComposableFilter locationSitesRefs(
      ComposableFilter Function($$LocationSitesTableFilterComposer f) f) {
    final $$LocationSitesTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.locationSites,
        getReferencedColumn: (t) => t.projectId,
        builder: (joinBuilder, parentComposers) =>
            $$LocationSitesTableFilterComposer(ComposerState($state.db,
                $state.db.locationSites, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter locationBasePlansRefs(
      ComposableFilter Function($$LocationBasePlansTableFilterComposer f) f) {
    final $$LocationBasePlansTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.locationBasePlans,
            getReferencedColumn: (t) => t.projectId,
            builder: (joinBuilder, parentComposers) =>
                $$LocationBasePlansTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.locationBasePlans,
                    joinBuilder,
                    parentComposers)));
    return f(composer);
  }

  ComposableFilter scenesRefs(
      ComposableFilter Function($$ScenesTableFilterComposer f) f) {
    final $$ScenesTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.scenes,
        getReferencedColumn: (t) => t.projectId,
        builder: (joinBuilder, parentComposers) => $$ScenesTableFilterComposer(
            ComposerState(
                $state.db, $state.db.scenes, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter shotsRefs(
      ComposableFilter Function($$ShotsTableFilterComposer f) f) {
    final $$ShotsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.shots,
        getReferencedColumn: (t) => t.projectId,
        builder: (joinBuilder, parentComposers) => $$ShotsTableFilterComposer(
            ComposerState(
                $state.db, $state.db.shots, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter projectEquipmentRefs(
      ComposableFilter Function($$ProjectEquipmentTableFilterComposer f) f) {
    final $$ProjectEquipmentTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.projectEquipment,
            getReferencedColumn: (t) => t.projectId,
            builder: (joinBuilder, parentComposers) =>
                $$ProjectEquipmentTableFilterComposer(ComposerState($state.db,
                    $state.db.projectEquipment, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter lookBiblesRefs(
      ComposableFilter Function($$LookBiblesTableFilterComposer f) f) {
    final $$LookBiblesTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.lookBibles,
        getReferencedColumn: (t) => t.projectId,
        builder: (joinBuilder, parentComposers) =>
            $$LookBiblesTableFilterComposer(ComposerState($state.db,
                $state.db.lookBibles, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter projectAnnotatedPdfsRefs(
      ComposableFilter Function($$ProjectAnnotatedPdfsTableFilterComposer f)
          f) {
    final $$ProjectAnnotatedPdfsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.projectAnnotatedPdfs,
            getReferencedColumn: (t) => t.projectId,
            builder: (joinBuilder, parentComposers) =>
                $$ProjectAnnotatedPdfsTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.projectAnnotatedPdfs,
                    joinBuilder,
                    parentComposers)));
    return f(composer);
  }

  ComposableFilter visualBiblesRefs(
      ComposableFilter Function($$VisualBiblesTableFilterComposer f) f) {
    final $$VisualBiblesTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.visualBibles,
        getReferencedColumn: (t) => t.projectId,
        builder: (joinBuilder, parentComposers) =>
            $$VisualBiblesTableFilterComposer(ComposerState($state.db,
                $state.db.visualBibles, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter moodboardImagesRefs(
      ComposableFilter Function($$MoodboardImagesTableFilterComposer f) f) {
    final $$MoodboardImagesTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.moodboardImages,
            getReferencedColumn: (t) => t.projectId,
            builder: (joinBuilder, parentComposers) =>
                $$MoodboardImagesTableFilterComposer(ComposerState($state.db,
                    $state.db.moodboardImages, joinBuilder, parentComposers)));
    return f(composer);
  }
}

class $$ProjectsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get director => $state.composableBuilder(
      column: $state.table.director,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get description => $state.composableBuilder(
      column: $state.table.description,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get clientName => $state.composableBuilder(
      column: $state.table.clientName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get status => $state.composableBuilder(
      column: $state.table.status,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get iconCode => $state.composableBuilder(
      column: $state.table.iconCode,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get coverImagePath => $state.composableBuilder(
      column: $state.table.coverImagePath,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get shootingStartDate => $state.composableBuilder(
      column: $state.table.shootingStartDate,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get shootingEndDate => $state.composableBuilder(
      column: $state.table.shootingEndDate,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get googleEmail => $state.composableBuilder(
      column: $state.table.googleEmail,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get scriptFilePath => $state.composableBuilder(
      column: $state.table.scriptFilePath,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get scriptFileName => $state.composableBuilder(
      column: $state.table.scriptFileName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get sortOrder => $state.composableBuilder(
      column: $state.table.sortOrder,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get updatedAt => $state.composableBuilder(
      column: $state.table.updatedAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$ProjectGroupsTableOrderingComposer get groupId {
    final $$ProjectGroupsTableOrderingComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.groupId,
            referencedTable: $state.db.projectGroups,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$ProjectGroupsTableOrderingComposer(ComposerState($state.db,
                    $state.db.projectGroups, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$LocationSitesTableCreateCompanionBuilder = LocationSitesCompanion
    Function({
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
typedef $$LocationSitesTableUpdateCompanionBuilder = LocationSitesCompanion
    Function({
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

class $$LocationSitesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocationSitesTable,
    LocationSite,
    $$LocationSitesTableFilterComposer,
    $$LocationSitesTableOrderingComposer,
    $$LocationSitesTableCreateCompanionBuilder,
    $$LocationSitesTableUpdateCompanionBuilder> {
  $$LocationSitesTableTableManager(_$AppDatabase db, $LocationSitesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$LocationSitesTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$LocationSitesTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
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
          }) =>
              LocationSitesCompanion(
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
          createCompanionCallback: ({
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
          }) =>
              LocationSitesCompanion.insert(
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
        ));
}

class $$LocationSitesTableFilterComposer
    extends FilterComposer<_$AppDatabase, $LocationSitesTable> {
  $$LocationSitesTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get description => $state.composableBuilder(
      column: $state.table.description,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get notes => $state.composableBuilder(
      column: $state.table.notes,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get floorPlanJson => $state.composableBuilder(
      column: $state.table.floorPlanJson,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get scanPath => $state.composableBuilder(
      column: $state.table.scanPath,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get scanSource => $state.composableBuilder(
      column: $state.table.scanSource,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get scanMetadataJson => $state.composableBuilder(
      column: $state.table.scanMetadataJson,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get sortOrder => $state.composableBuilder(
      column: $state.table.sortOrder,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $state.db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$ProjectsTableFilterComposer(ComposerState(
                $state.db, $state.db.projects, joinBuilder, parentComposers)));
    return composer;
  }

  ComposableFilter locationBasePlansRefs(
      ComposableFilter Function($$LocationBasePlansTableFilterComposer f) f) {
    final $$LocationBasePlansTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.locationBasePlans,
            getReferencedColumn: (t) => t.siteId,
            builder: (joinBuilder, parentComposers) =>
                $$LocationBasePlansTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.locationBasePlans,
                    joinBuilder,
                    parentComposers)));
    return f(composer);
  }

  ComposableFilter scenesRefs(
      ComposableFilter Function($$ScenesTableFilterComposer f) f) {
    final $$ScenesTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.scenes,
        getReferencedColumn: (t) => t.locationSiteId,
        builder: (joinBuilder, parentComposers) => $$ScenesTableFilterComposer(
            ComposerState(
                $state.db, $state.db.scenes, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter siteImagesRefs(
      ComposableFilter Function($$SiteImagesTableFilterComposer f) f) {
    final $$SiteImagesTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.siteImages,
        getReferencedColumn: (t) => t.siteId,
        builder: (joinBuilder, parentComposers) =>
            $$SiteImagesTableFilterComposer(ComposerState($state.db,
                $state.db.siteImages, joinBuilder, parentComposers)));
    return f(composer);
  }
}

class $$LocationSitesTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $LocationSitesTable> {
  $$LocationSitesTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get description => $state.composableBuilder(
      column: $state.table.description,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get notes => $state.composableBuilder(
      column: $state.table.notes,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get floorPlanJson => $state.composableBuilder(
      column: $state.table.floorPlanJson,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get scanPath => $state.composableBuilder(
      column: $state.table.scanPath,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get scanSource => $state.composableBuilder(
      column: $state.table.scanSource,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get scanMetadataJson => $state.composableBuilder(
      column: $state.table.scanMetadataJson,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get sortOrder => $state.composableBuilder(
      column: $state.table.sortOrder,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $state.db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$ProjectsTableOrderingComposer(ComposerState(
                $state.db, $state.db.projects, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$LocationBasePlansTableCreateCompanionBuilder
    = LocationBasePlansCompanion Function({
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
typedef $$LocationBasePlansTableUpdateCompanionBuilder
    = LocationBasePlansCompanion Function({
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

class $$LocationBasePlansTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocationBasePlansTable,
    LocationBasePlan,
    $$LocationBasePlansTableFilterComposer,
    $$LocationBasePlansTableOrderingComposer,
    $$LocationBasePlansTableCreateCompanionBuilder,
    $$LocationBasePlansTableUpdateCompanionBuilder> {
  $$LocationBasePlansTableTableManager(
      _$AppDatabase db, $LocationBasePlansTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$LocationBasePlansTableFilterComposer(ComposerState(db, table)),
          orderingComposer: $$LocationBasePlansTableOrderingComposer(
              ComposerState(db, table)),
          updateCompanionCallback: ({
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
          }) =>
              LocationBasePlansCompanion(
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
          createCompanionCallback: ({
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
          }) =>
              LocationBasePlansCompanion.insert(
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
        ));
}

class $$LocationBasePlansTableFilterComposer
    extends FilterComposer<_$AppDatabase, $LocationBasePlansTable> {
  $$LocationBasePlansTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get locationName => $state.composableBuilder(
      column: $state.table.locationName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get description => $state.composableBuilder(
      column: $state.table.description,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get imagePath => $state.composableBuilder(
      column: $state.table.imagePath,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get color => $state.composableBuilder(
      column: $state.table.color,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get notes => $state.composableBuilder(
      column: $state.table.notes,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get model3dPath => $state.composableBuilder(
      column: $state.table.model3dPath,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get floorPlanJson => $state.composableBuilder(
      column: $state.table.floorPlanJson,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get scanPath => $state.composableBuilder(
      column: $state.table.scanPath,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get scanSource => $state.composableBuilder(
      column: $state.table.scanSource,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get scanMetadataJson => $state.composableBuilder(
      column: $state.table.scanMetadataJson,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get sortOrder => $state.composableBuilder(
      column: $state.table.sortOrder,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $state.db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$ProjectsTableFilterComposer(ComposerState(
                $state.db, $state.db.projects, joinBuilder, parentComposers)));
    return composer;
  }

  $$LocationSitesTableFilterComposer get siteId {
    final $$LocationSitesTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.siteId,
        referencedTable: $state.db.locationSites,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$LocationSitesTableFilterComposer(ComposerState($state.db,
                $state.db.locationSites, joinBuilder, parentComposers)));
    return composer;
  }

  ComposableFilter scenesRefs(
      ComposableFilter Function($$ScenesTableFilterComposer f) f) {
    final $$ScenesTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.scenes,
        getReferencedColumn: (t) => t.locationId,
        builder: (joinBuilder, parentComposers) => $$ScenesTableFilterComposer(
            ComposerState(
                $state.db, $state.db.scenes, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter locationImagesRefs(
      ComposableFilter Function($$LocationImagesTableFilterComposer f) f) {
    final $$LocationImagesTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.locationImages,
        getReferencedColumn: (t) => t.locationId,
        builder: (joinBuilder, parentComposers) =>
            $$LocationImagesTableFilterComposer(ComposerState($state.db,
                $state.db.locationImages, joinBuilder, parentComposers)));
    return f(composer);
  }
}

class $$LocationBasePlansTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $LocationBasePlansTable> {
  $$LocationBasePlansTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get locationName => $state.composableBuilder(
      column: $state.table.locationName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get description => $state.composableBuilder(
      column: $state.table.description,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get imagePath => $state.composableBuilder(
      column: $state.table.imagePath,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get color => $state.composableBuilder(
      column: $state.table.color,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get notes => $state.composableBuilder(
      column: $state.table.notes,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get model3dPath => $state.composableBuilder(
      column: $state.table.model3dPath,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get floorPlanJson => $state.composableBuilder(
      column: $state.table.floorPlanJson,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get scanPath => $state.composableBuilder(
      column: $state.table.scanPath,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get scanSource => $state.composableBuilder(
      column: $state.table.scanSource,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get scanMetadataJson => $state.composableBuilder(
      column: $state.table.scanMetadataJson,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get sortOrder => $state.composableBuilder(
      column: $state.table.sortOrder,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $state.db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$ProjectsTableOrderingComposer(ComposerState(
                $state.db, $state.db.projects, joinBuilder, parentComposers)));
    return composer;
  }

  $$LocationSitesTableOrderingComposer get siteId {
    final $$LocationSitesTableOrderingComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.siteId,
            referencedTable: $state.db.locationSites,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$LocationSitesTableOrderingComposer(ComposerState($state.db,
                    $state.db.locationSites, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$ScenesTableCreateCompanionBuilder = ScenesCompanion Function({
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
typedef $$ScenesTableUpdateCompanionBuilder = ScenesCompanion Function({
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

class $$ScenesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ScenesTable,
    Scene,
    $$ScenesTableFilterComposer,
    $$ScenesTableOrderingComposer,
    $$ScenesTableCreateCompanionBuilder,
    $$ScenesTableUpdateCompanionBuilder> {
  $$ScenesTableTableManager(_$AppDatabase db, $ScenesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$ScenesTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$ScenesTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
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
          }) =>
              ScenesCompanion(
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
          createCompanionCallback: ({
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
          }) =>
              ScenesCompanion.insert(
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
        ));
}

class $$ScenesTableFilterComposer
    extends FilterComposer<_$AppDatabase, $ScenesTable> {
  $$ScenesTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get number => $state.composableBuilder(
      column: $state.table.number,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get locationCanonical => $state.composableBuilder(
      column: $state.table.locationCanonical,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get locationPureName => $state.composableBuilder(
      column: $state.table.locationPureName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get intExt => $state.composableBuilder(
      column: $state.table.intExt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get dayNight => $state.composableBuilder(
      column: $state.table.dayNight,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get locationColor => $state.composableBuilder(
      column: $state.table.locationColor,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get description => $state.composableBuilder(
      column: $state.table.description,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get actionText => $state.composableBuilder(
      column: $state.table.actionText,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get sourceStartIndex => $state.composableBuilder(
      column: $state.table.sourceStartIndex,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get durationMinutes => $state.composableBuilder(
      column: $state.table.durationMinutes,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get autoNumbering => $state.composableBuilder(
      column: $state.table.autoNumbering,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get sortOrder => $state.composableBuilder(
      column: $state.table.sortOrder,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $state.db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$ProjectsTableFilterComposer(ComposerState(
                $state.db, $state.db.projects, joinBuilder, parentComposers)));
    return composer;
  }

  $$LocationSitesTableFilterComposer get locationSiteId {
    final $$LocationSitesTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.locationSiteId,
        referencedTable: $state.db.locationSites,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$LocationSitesTableFilterComposer(ComposerState($state.db,
                $state.db.locationSites, joinBuilder, parentComposers)));
    return composer;
  }

  $$LocationBasePlansTableFilterComposer get locationId {
    final $$LocationBasePlansTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.locationId,
            referencedTable: $state.db.locationBasePlans,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$LocationBasePlansTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.locationBasePlans,
                    joinBuilder,
                    parentComposers)));
    return composer;
  }

  ComposableFilter shotsRefs(
      ComposableFilter Function($$ShotsTableFilterComposer f) f) {
    final $$ShotsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.shots,
        getReferencedColumn: (t) => t.sceneId,
        builder: (joinBuilder, parentComposers) => $$ShotsTableFilterComposer(
            ComposerState(
                $state.db, $state.db.shots, joinBuilder, parentComposers)));
    return f(composer);
  }
}

class $$ScenesTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $ScenesTable> {
  $$ScenesTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get number => $state.composableBuilder(
      column: $state.table.number,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get locationCanonical => $state.composableBuilder(
      column: $state.table.locationCanonical,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get locationPureName => $state.composableBuilder(
      column: $state.table.locationPureName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get intExt => $state.composableBuilder(
      column: $state.table.intExt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get dayNight => $state.composableBuilder(
      column: $state.table.dayNight,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get locationColor => $state.composableBuilder(
      column: $state.table.locationColor,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get description => $state.composableBuilder(
      column: $state.table.description,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get actionText => $state.composableBuilder(
      column: $state.table.actionText,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get sourceStartIndex => $state.composableBuilder(
      column: $state.table.sourceStartIndex,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get durationMinutes => $state.composableBuilder(
      column: $state.table.durationMinutes,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get autoNumbering => $state.composableBuilder(
      column: $state.table.autoNumbering,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get sortOrder => $state.composableBuilder(
      column: $state.table.sortOrder,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $state.db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$ProjectsTableOrderingComposer(ComposerState(
                $state.db, $state.db.projects, joinBuilder, parentComposers)));
    return composer;
  }

  $$LocationSitesTableOrderingComposer get locationSiteId {
    final $$LocationSitesTableOrderingComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.locationSiteId,
            referencedTable: $state.db.locationSites,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$LocationSitesTableOrderingComposer(ComposerState($state.db,
                    $state.db.locationSites, joinBuilder, parentComposers)));
    return composer;
  }

  $$LocationBasePlansTableOrderingComposer get locationId {
    final $$LocationBasePlansTableOrderingComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.locationId,
            referencedTable: $state.db.locationBasePlans,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$LocationBasePlansTableOrderingComposer(ComposerState(
                    $state.db,
                    $state.db.locationBasePlans,
                    joinBuilder,
                    parentComposers)));
    return composer;
  }
}

typedef $$ShotsTableCreateCompanionBuilder = ShotsCompanion Function({
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
typedef $$ShotsTableUpdateCompanionBuilder = ShotsCompanion Function({
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

class $$ShotsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ShotsTable,
    Shot,
    $$ShotsTableFilterComposer,
    $$ShotsTableOrderingComposer,
    $$ShotsTableCreateCompanionBuilder,
    $$ShotsTableUpdateCompanionBuilder> {
  $$ShotsTableTableManager(_$AppDatabase db, $ShotsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$ShotsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$ShotsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
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
          }) =>
              ShotsCompanion(
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
          createCompanionCallback: ({
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
          }) =>
              ShotsCompanion.insert(
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
        ));
}

class $$ShotsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $ShotsTable> {
  $$ShotsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get number => $state.composableBuilder(
      column: $state.table.number,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get framing => $state.composableBuilder(
      column: $state.table.framing,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get lens => $state.composableBuilder(
      column: $state.table.lens,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get angle => $state.composableBuilder(
      column: $state.table.angle,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get movement => $state.composableBuilder(
      column: $state.table.movement,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get fStop => $state.composableBuilder(
      column: $state.table.fStop,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get shutterAngle => $state.composableBuilder(
      column: $state.table.shutterAngle,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get fps => $state.composableBuilder(
      column: $state.table.fps,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get action => $state.composableBuilder(
      column: $state.table.action,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get notes => $state.composableBuilder(
      column: $state.table.notes,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get notesHighlight => $state.composableBuilder(
      column: $state.table.notesHighlight,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get description => $state.composableBuilder(
      column: $state.table.description,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get referenceImagePath => $state.composableBuilder(
      column: $state.table.referenceImagePath,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get cameraPlanImagePath => $state.composableBuilder(
      column: $state.table.cameraPlanImagePath,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get autoNumbering => $state.composableBuilder(
      column: $state.table.autoNumbering,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get sortOrder => $state.composableBuilder(
      column: $state.table.sortOrder,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$ScenesTableFilterComposer get sceneId {
    final $$ScenesTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sceneId,
        referencedTable: $state.db.scenes,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$ScenesTableFilterComposer(
            ComposerState(
                $state.db, $state.db.scenes, joinBuilder, parentComposers)));
    return composer;
  }

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $state.db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$ProjectsTableFilterComposer(ComposerState(
                $state.db, $state.db.projects, joinBuilder, parentComposers)));
    return composer;
  }

  ComposableFilter shotReferencesRefs(
      ComposableFilter Function($$ShotReferencesTableFilterComposer f) f) {
    final $$ShotReferencesTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.shotReferences,
        getReferencedColumn: (t) => t.shotId,
        builder: (joinBuilder, parentComposers) =>
            $$ShotReferencesTableFilterComposer(ComposerState($state.db,
                $state.db.shotReferences, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter cameraPlanElementsRefs(
      ComposableFilter Function($$CameraPlanElementsTableFilterComposer f) f) {
    final $$CameraPlanElementsTableFilterComposer composer = $state
        .composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.cameraPlanElements,
            getReferencedColumn: (t) => t.shotId,
            builder: (joinBuilder, parentComposers) =>
                $$CameraPlanElementsTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.cameraPlanElements,
                    joinBuilder,
                    parentComposers)));
    return f(composer);
  }
}

class $$ShotsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $ShotsTable> {
  $$ShotsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get number => $state.composableBuilder(
      column: $state.table.number,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get framing => $state.composableBuilder(
      column: $state.table.framing,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get lens => $state.composableBuilder(
      column: $state.table.lens,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get angle => $state.composableBuilder(
      column: $state.table.angle,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get movement => $state.composableBuilder(
      column: $state.table.movement,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get fStop => $state.composableBuilder(
      column: $state.table.fStop,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get shutterAngle => $state.composableBuilder(
      column: $state.table.shutterAngle,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get fps => $state.composableBuilder(
      column: $state.table.fps,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get action => $state.composableBuilder(
      column: $state.table.action,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get notes => $state.composableBuilder(
      column: $state.table.notes,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get notesHighlight => $state.composableBuilder(
      column: $state.table.notesHighlight,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get description => $state.composableBuilder(
      column: $state.table.description,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get referenceImagePath => $state.composableBuilder(
      column: $state.table.referenceImagePath,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get cameraPlanImagePath => $state.composableBuilder(
      column: $state.table.cameraPlanImagePath,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get autoNumbering => $state.composableBuilder(
      column: $state.table.autoNumbering,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get sortOrder => $state.composableBuilder(
      column: $state.table.sortOrder,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$ScenesTableOrderingComposer get sceneId {
    final $$ScenesTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sceneId,
        referencedTable: $state.db.scenes,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$ScenesTableOrderingComposer(ComposerState(
                $state.db, $state.db.scenes, joinBuilder, parentComposers)));
    return composer;
  }

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $state.db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$ProjectsTableOrderingComposer(ComposerState(
                $state.db, $state.db.projects, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$ShotReferencesTableCreateCompanionBuilder = ShotReferencesCompanion
    Function({
  Value<int> id,
  required int shotId,
  required String imagePath,
  Value<String> source,
  Value<int> sortOrder,
});
typedef $$ShotReferencesTableUpdateCompanionBuilder = ShotReferencesCompanion
    Function({
  Value<int> id,
  Value<int> shotId,
  Value<String> imagePath,
  Value<String> source,
  Value<int> sortOrder,
});

class $$ShotReferencesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ShotReferencesTable,
    ShotReference,
    $$ShotReferencesTableFilterComposer,
    $$ShotReferencesTableOrderingComposer,
    $$ShotReferencesTableCreateCompanionBuilder,
    $$ShotReferencesTableUpdateCompanionBuilder> {
  $$ShotReferencesTableTableManager(
      _$AppDatabase db, $ShotReferencesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$ShotReferencesTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$ShotReferencesTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> shotId = const Value.absent(),
            Value<String> imagePath = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
          }) =>
              ShotReferencesCompanion(
            id: id,
            shotId: shotId,
            imagePath: imagePath,
            source: source,
            sortOrder: sortOrder,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int shotId,
            required String imagePath,
            Value<String> source = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
          }) =>
              ShotReferencesCompanion.insert(
            id: id,
            shotId: shotId,
            imagePath: imagePath,
            source: source,
            sortOrder: sortOrder,
          ),
        ));
}

class $$ShotReferencesTableFilterComposer
    extends FilterComposer<_$AppDatabase, $ShotReferencesTable> {
  $$ShotReferencesTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get imagePath => $state.composableBuilder(
      column: $state.table.imagePath,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get source => $state.composableBuilder(
      column: $state.table.source,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get sortOrder => $state.composableBuilder(
      column: $state.table.sortOrder,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$ShotsTableFilterComposer get shotId {
    final $$ShotsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.shotId,
        referencedTable: $state.db.shots,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$ShotsTableFilterComposer(
            ComposerState(
                $state.db, $state.db.shots, joinBuilder, parentComposers)));
    return composer;
  }
}

class $$ShotReferencesTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $ShotReferencesTable> {
  $$ShotReferencesTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get imagePath => $state.composableBuilder(
      column: $state.table.imagePath,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get source => $state.composableBuilder(
      column: $state.table.source,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get sortOrder => $state.composableBuilder(
      column: $state.table.sortOrder,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$ShotsTableOrderingComposer get shotId {
    final $$ShotsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.shotId,
        referencedTable: $state.db.shots,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$ShotsTableOrderingComposer(
            ComposerState(
                $state.db, $state.db.shots, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$CameraPlanElementsTableCreateCompanionBuilder
    = CameraPlanElementsCompanion Function({
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
typedef $$CameraPlanElementsTableUpdateCompanionBuilder
    = CameraPlanElementsCompanion Function({
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

class $$CameraPlanElementsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CameraPlanElementsTable,
    CameraPlanElement,
    $$CameraPlanElementsTableFilterComposer,
    $$CameraPlanElementsTableOrderingComposer,
    $$CameraPlanElementsTableCreateCompanionBuilder,
    $$CameraPlanElementsTableUpdateCompanionBuilder> {
  $$CameraPlanElementsTableTableManager(
      _$AppDatabase db, $CameraPlanElementsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$CameraPlanElementsTableFilterComposer(ComposerState(db, table)),
          orderingComposer: $$CameraPlanElementsTableOrderingComposer(
              ComposerState(db, table)),
          updateCompanionCallback: ({
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
          }) =>
              CameraPlanElementsCompanion(
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
          createCompanionCallback: ({
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
          }) =>
              CameraPlanElementsCompanion.insert(
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
        ));
}

class $$CameraPlanElementsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $CameraPlanElementsTable> {
  $$CameraPlanElementsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get type => $state.composableBuilder(
      column: $state.table.type,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get x => $state.composableBuilder(
      column: $state.table.x,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get y => $state.composableBuilder(
      column: $state.table.y,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get rotation => $state.composableBuilder(
      column: $state.table.rotation,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get label => $state.composableBuilder(
      column: $state.table.label,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get color => $state.composableBuilder(
      column: $state.table.color,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get cameraStabilization => $state.composableBuilder(
      column: $state.table.cameraStabilization,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get cameraLens => $state.composableBuilder(
      column: $state.table.cameraLens,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get cameraLetter => $state.composableBuilder(
      column: $state.table.cameraLetter,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get cameraNumber => $state.composableBuilder(
      column: $state.table.cameraNumber,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get lightType => $state.composableBuilder(
      column: $state.table.lightType,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get lukaCompatible => $state.composableBuilder(
      column: $state.table.lukaCompatible,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get lukaFixtureId => $state.composableBuilder(
      column: $state.table.lukaFixtureId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get externalMappingJson => $state.composableBuilder(
      column: $state.table.externalMappingJson,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get sortOrder => $state.composableBuilder(
      column: $state.table.sortOrder,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$ShotsTableFilterComposer get shotId {
    final $$ShotsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.shotId,
        referencedTable: $state.db.shots,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$ShotsTableFilterComposer(
            ComposerState(
                $state.db, $state.db.shots, joinBuilder, parentComposers)));
    return composer;
  }

  ComposableFilter cameraPathPointsRefs(
      ComposableFilter Function($$CameraPathPointsTableFilterComposer f) f) {
    final $$CameraPathPointsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.cameraPathPoints,
            getReferencedColumn: (t) => t.elementId,
            builder: (joinBuilder, parentComposers) =>
                $$CameraPathPointsTableFilterComposer(ComposerState($state.db,
                    $state.db.cameraPathPoints, joinBuilder, parentComposers)));
    return f(composer);
  }
}

class $$CameraPlanElementsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $CameraPlanElementsTable> {
  $$CameraPlanElementsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get type => $state.composableBuilder(
      column: $state.table.type,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get x => $state.composableBuilder(
      column: $state.table.x,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get y => $state.composableBuilder(
      column: $state.table.y,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get rotation => $state.composableBuilder(
      column: $state.table.rotation,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get label => $state.composableBuilder(
      column: $state.table.label,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get color => $state.composableBuilder(
      column: $state.table.color,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get cameraStabilization => $state.composableBuilder(
      column: $state.table.cameraStabilization,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get cameraLens => $state.composableBuilder(
      column: $state.table.cameraLens,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get cameraLetter => $state.composableBuilder(
      column: $state.table.cameraLetter,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get cameraNumber => $state.composableBuilder(
      column: $state.table.cameraNumber,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get lightType => $state.composableBuilder(
      column: $state.table.lightType,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get lukaCompatible => $state.composableBuilder(
      column: $state.table.lukaCompatible,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get lukaFixtureId => $state.composableBuilder(
      column: $state.table.lukaFixtureId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get externalMappingJson => $state.composableBuilder(
      column: $state.table.externalMappingJson,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get sortOrder => $state.composableBuilder(
      column: $state.table.sortOrder,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$ShotsTableOrderingComposer get shotId {
    final $$ShotsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.shotId,
        referencedTable: $state.db.shots,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$ShotsTableOrderingComposer(
            ComposerState(
                $state.db, $state.db.shots, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$CameraPathPointsTableCreateCompanionBuilder
    = CameraPathPointsCompanion Function({
  Value<int> id,
  required int elementId,
  required int pointNumber,
  required double x,
  required double y,
});
typedef $$CameraPathPointsTableUpdateCompanionBuilder
    = CameraPathPointsCompanion Function({
  Value<int> id,
  Value<int> elementId,
  Value<int> pointNumber,
  Value<double> x,
  Value<double> y,
});

class $$CameraPathPointsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CameraPathPointsTable,
    CameraPathPoint,
    $$CameraPathPointsTableFilterComposer,
    $$CameraPathPointsTableOrderingComposer,
    $$CameraPathPointsTableCreateCompanionBuilder,
    $$CameraPathPointsTableUpdateCompanionBuilder> {
  $$CameraPathPointsTableTableManager(
      _$AppDatabase db, $CameraPathPointsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$CameraPathPointsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$CameraPathPointsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> elementId = const Value.absent(),
            Value<int> pointNumber = const Value.absent(),
            Value<double> x = const Value.absent(),
            Value<double> y = const Value.absent(),
          }) =>
              CameraPathPointsCompanion(
            id: id,
            elementId: elementId,
            pointNumber: pointNumber,
            x: x,
            y: y,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int elementId,
            required int pointNumber,
            required double x,
            required double y,
          }) =>
              CameraPathPointsCompanion.insert(
            id: id,
            elementId: elementId,
            pointNumber: pointNumber,
            x: x,
            y: y,
          ),
        ));
}

class $$CameraPathPointsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $CameraPathPointsTable> {
  $$CameraPathPointsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get pointNumber => $state.composableBuilder(
      column: $state.table.pointNumber,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get x => $state.composableBuilder(
      column: $state.table.x,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get y => $state.composableBuilder(
      column: $state.table.y,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$CameraPlanElementsTableFilterComposer get elementId {
    final $$CameraPlanElementsTableFilterComposer composer = $state
        .composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.elementId,
            referencedTable: $state.db.cameraPlanElements,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$CameraPlanElementsTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.cameraPlanElements,
                    joinBuilder,
                    parentComposers)));
    return composer;
  }
}

class $$CameraPathPointsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $CameraPathPointsTable> {
  $$CameraPathPointsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get pointNumber => $state.composableBuilder(
      column: $state.table.pointNumber,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get x => $state.composableBuilder(
      column: $state.table.x,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get y => $state.composableBuilder(
      column: $state.table.y,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$CameraPlanElementsTableOrderingComposer get elementId {
    final $$CameraPlanElementsTableOrderingComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.elementId,
            referencedTable: $state.db.cameraPlanElements,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$CameraPlanElementsTableOrderingComposer(ComposerState(
                    $state.db,
                    $state.db.cameraPlanElements,
                    joinBuilder,
                    parentComposers)));
    return composer;
  }
}

typedef $$LocationImagesTableCreateCompanionBuilder = LocationImagesCompanion
    Function({
  Value<int> id,
  required int locationId,
  required String imagePath,
  Value<String?> caption,
  Value<String> kind,
  Value<String?> timeOfDay,
  Value<int> sortOrder,
});
typedef $$LocationImagesTableUpdateCompanionBuilder = LocationImagesCompanion
    Function({
  Value<int> id,
  Value<int> locationId,
  Value<String> imagePath,
  Value<String?> caption,
  Value<String> kind,
  Value<String?> timeOfDay,
  Value<int> sortOrder,
});

class $$LocationImagesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocationImagesTable,
    LocationImage,
    $$LocationImagesTableFilterComposer,
    $$LocationImagesTableOrderingComposer,
    $$LocationImagesTableCreateCompanionBuilder,
    $$LocationImagesTableUpdateCompanionBuilder> {
  $$LocationImagesTableTableManager(
      _$AppDatabase db, $LocationImagesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$LocationImagesTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$LocationImagesTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> locationId = const Value.absent(),
            Value<String> imagePath = const Value.absent(),
            Value<String?> caption = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String?> timeOfDay = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
          }) =>
              LocationImagesCompanion(
            id: id,
            locationId: locationId,
            imagePath: imagePath,
            caption: caption,
            kind: kind,
            timeOfDay: timeOfDay,
            sortOrder: sortOrder,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int locationId,
            required String imagePath,
            Value<String?> caption = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String?> timeOfDay = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
          }) =>
              LocationImagesCompanion.insert(
            id: id,
            locationId: locationId,
            imagePath: imagePath,
            caption: caption,
            kind: kind,
            timeOfDay: timeOfDay,
            sortOrder: sortOrder,
          ),
        ));
}

class $$LocationImagesTableFilterComposer
    extends FilterComposer<_$AppDatabase, $LocationImagesTable> {
  $$LocationImagesTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get imagePath => $state.composableBuilder(
      column: $state.table.imagePath,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get caption => $state.composableBuilder(
      column: $state.table.caption,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get kind => $state.composableBuilder(
      column: $state.table.kind,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get timeOfDay => $state.composableBuilder(
      column: $state.table.timeOfDay,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get sortOrder => $state.composableBuilder(
      column: $state.table.sortOrder,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$LocationBasePlansTableFilterComposer get locationId {
    final $$LocationBasePlansTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.locationId,
            referencedTable: $state.db.locationBasePlans,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$LocationBasePlansTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.locationBasePlans,
                    joinBuilder,
                    parentComposers)));
    return composer;
  }
}

class $$LocationImagesTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $LocationImagesTable> {
  $$LocationImagesTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get imagePath => $state.composableBuilder(
      column: $state.table.imagePath,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get caption => $state.composableBuilder(
      column: $state.table.caption,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get kind => $state.composableBuilder(
      column: $state.table.kind,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get timeOfDay => $state.composableBuilder(
      column: $state.table.timeOfDay,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get sortOrder => $state.composableBuilder(
      column: $state.table.sortOrder,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$LocationBasePlansTableOrderingComposer get locationId {
    final $$LocationBasePlansTableOrderingComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.locationId,
            referencedTable: $state.db.locationBasePlans,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$LocationBasePlansTableOrderingComposer(ComposerState(
                    $state.db,
                    $state.db.locationBasePlans,
                    joinBuilder,
                    parentComposers)));
    return composer;
  }
}

typedef $$SiteImagesTableCreateCompanionBuilder = SiteImagesCompanion Function({
  Value<int> id,
  required int siteId,
  required String imagePath,
  Value<String?> caption,
  Value<String> kind,
  Value<String?> timeOfDay,
  Value<int> sortOrder,
});
typedef $$SiteImagesTableUpdateCompanionBuilder = SiteImagesCompanion Function({
  Value<int> id,
  Value<int> siteId,
  Value<String> imagePath,
  Value<String?> caption,
  Value<String> kind,
  Value<String?> timeOfDay,
  Value<int> sortOrder,
});

class $$SiteImagesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SiteImagesTable,
    SiteImage,
    $$SiteImagesTableFilterComposer,
    $$SiteImagesTableOrderingComposer,
    $$SiteImagesTableCreateCompanionBuilder,
    $$SiteImagesTableUpdateCompanionBuilder> {
  $$SiteImagesTableTableManager(_$AppDatabase db, $SiteImagesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$SiteImagesTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$SiteImagesTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> siteId = const Value.absent(),
            Value<String> imagePath = const Value.absent(),
            Value<String?> caption = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String?> timeOfDay = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
          }) =>
              SiteImagesCompanion(
            id: id,
            siteId: siteId,
            imagePath: imagePath,
            caption: caption,
            kind: kind,
            timeOfDay: timeOfDay,
            sortOrder: sortOrder,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int siteId,
            required String imagePath,
            Value<String?> caption = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String?> timeOfDay = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
          }) =>
              SiteImagesCompanion.insert(
            id: id,
            siteId: siteId,
            imagePath: imagePath,
            caption: caption,
            kind: kind,
            timeOfDay: timeOfDay,
            sortOrder: sortOrder,
          ),
        ));
}

class $$SiteImagesTableFilterComposer
    extends FilterComposer<_$AppDatabase, $SiteImagesTable> {
  $$SiteImagesTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get imagePath => $state.composableBuilder(
      column: $state.table.imagePath,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get caption => $state.composableBuilder(
      column: $state.table.caption,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get kind => $state.composableBuilder(
      column: $state.table.kind,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get timeOfDay => $state.composableBuilder(
      column: $state.table.timeOfDay,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get sortOrder => $state.composableBuilder(
      column: $state.table.sortOrder,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$LocationSitesTableFilterComposer get siteId {
    final $$LocationSitesTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.siteId,
        referencedTable: $state.db.locationSites,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$LocationSitesTableFilterComposer(ComposerState($state.db,
                $state.db.locationSites, joinBuilder, parentComposers)));
    return composer;
  }
}

class $$SiteImagesTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $SiteImagesTable> {
  $$SiteImagesTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get imagePath => $state.composableBuilder(
      column: $state.table.imagePath,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get caption => $state.composableBuilder(
      column: $state.table.caption,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get kind => $state.composableBuilder(
      column: $state.table.kind,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get timeOfDay => $state.composableBuilder(
      column: $state.table.timeOfDay,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get sortOrder => $state.composableBuilder(
      column: $state.table.sortOrder,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$LocationSitesTableOrderingComposer get siteId {
    final $$LocationSitesTableOrderingComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.siteId,
            referencedTable: $state.db.locationSites,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$LocationSitesTableOrderingComposer(ComposerState($state.db,
                    $state.db.locationSites, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$CamerasTableCreateCompanionBuilder = CamerasCompanion Function({
  Value<int> id,
  required String brand,
  required String model,
  required double sensorWidthMm,
  required double sensorHeightMm,
  Value<String?> recordingFormats,
  Value<String?> notes,
});
typedef $$CamerasTableUpdateCompanionBuilder = CamerasCompanion Function({
  Value<int> id,
  Value<String> brand,
  Value<String> model,
  Value<double> sensorWidthMm,
  Value<double> sensorHeightMm,
  Value<String?> recordingFormats,
  Value<String?> notes,
});

class $$CamerasTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CamerasTable,
    Camera,
    $$CamerasTableFilterComposer,
    $$CamerasTableOrderingComposer,
    $$CamerasTableCreateCompanionBuilder,
    $$CamerasTableUpdateCompanionBuilder> {
  $$CamerasTableTableManager(_$AppDatabase db, $CamerasTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$CamerasTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$CamerasTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> brand = const Value.absent(),
            Value<String> model = const Value.absent(),
            Value<double> sensorWidthMm = const Value.absent(),
            Value<double> sensorHeightMm = const Value.absent(),
            Value<String?> recordingFormats = const Value.absent(),
            Value<String?> notes = const Value.absent(),
          }) =>
              CamerasCompanion(
            id: id,
            brand: brand,
            model: model,
            sensorWidthMm: sensorWidthMm,
            sensorHeightMm: sensorHeightMm,
            recordingFormats: recordingFormats,
            notes: notes,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String brand,
            required String model,
            required double sensorWidthMm,
            required double sensorHeightMm,
            Value<String?> recordingFormats = const Value.absent(),
            Value<String?> notes = const Value.absent(),
          }) =>
              CamerasCompanion.insert(
            id: id,
            brand: brand,
            model: model,
            sensorWidthMm: sensorWidthMm,
            sensorHeightMm: sensorHeightMm,
            recordingFormats: recordingFormats,
            notes: notes,
          ),
        ));
}

class $$CamerasTableFilterComposer
    extends FilterComposer<_$AppDatabase, $CamerasTable> {
  $$CamerasTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get brand => $state.composableBuilder(
      column: $state.table.brand,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get model => $state.composableBuilder(
      column: $state.table.model,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get sensorWidthMm => $state.composableBuilder(
      column: $state.table.sensorWidthMm,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get sensorHeightMm => $state.composableBuilder(
      column: $state.table.sensorHeightMm,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get recordingFormats => $state.composableBuilder(
      column: $state.table.recordingFormats,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get notes => $state.composableBuilder(
      column: $state.table.notes,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$CamerasTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $CamerasTable> {
  $$CamerasTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get brand => $state.composableBuilder(
      column: $state.table.brand,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get model => $state.composableBuilder(
      column: $state.table.model,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get sensorWidthMm => $state.composableBuilder(
      column: $state.table.sensorWidthMm,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get sensorHeightMm => $state.composableBuilder(
      column: $state.table.sensorHeightMm,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get recordingFormats => $state.composableBuilder(
      column: $state.table.recordingFormats,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get notes => $state.composableBuilder(
      column: $state.table.notes,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$LensesTableCreateCompanionBuilder = LensesCompanion Function({
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
typedef $$LensesTableUpdateCompanionBuilder = LensesCompanion Function({
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

class $$LensesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LensesTable,
    Lense,
    $$LensesTableFilterComposer,
    $$LensesTableOrderingComposer,
    $$LensesTableCreateCompanionBuilder,
    $$LensesTableUpdateCompanionBuilder> {
  $$LensesTableTableManager(_$AppDatabase db, $LensesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$LensesTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$LensesTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> brand = const Value.absent(),
            Value<String> model = const Value.absent(),
            Value<double> focalLength = const Value.absent(),
            Value<double?> focalMin = const Value.absent(),
            Value<double?> focalMax = const Value.absent(),
            Value<double> minTStop = const Value.absent(),
            Value<String> formatCoverage = const Value.absent(),
            Value<String?> notes = const Value.absent(),
          }) =>
              LensesCompanion(
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
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String brand,
            required String model,
            required double focalLength,
            Value<double?> focalMin = const Value.absent(),
            Value<double?> focalMax = const Value.absent(),
            required double minTStop,
            required String formatCoverage,
            Value<String?> notes = const Value.absent(),
          }) =>
              LensesCompanion.insert(
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
        ));
}

class $$LensesTableFilterComposer
    extends FilterComposer<_$AppDatabase, $LensesTable> {
  $$LensesTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get brand => $state.composableBuilder(
      column: $state.table.brand,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get model => $state.composableBuilder(
      column: $state.table.model,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get focalLength => $state.composableBuilder(
      column: $state.table.focalLength,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get focalMin => $state.composableBuilder(
      column: $state.table.focalMin,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get focalMax => $state.composableBuilder(
      column: $state.table.focalMax,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get minTStop => $state.composableBuilder(
      column: $state.table.minTStop,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get formatCoverage => $state.composableBuilder(
      column: $state.table.formatCoverage,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get notes => $state.composableBuilder(
      column: $state.table.notes,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ComposableFilter visualBiblesRefs(
      ComposableFilter Function($$VisualBiblesTableFilterComposer f) f) {
    final $$VisualBiblesTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.visualBibles,
        getReferencedColumn: (t) => t.primaryLensId,
        builder: (joinBuilder, parentComposers) =>
            $$VisualBiblesTableFilterComposer(ComposerState($state.db,
                $state.db.visualBibles, joinBuilder, parentComposers)));
    return f(composer);
  }
}

class $$LensesTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $LensesTable> {
  $$LensesTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get brand => $state.composableBuilder(
      column: $state.table.brand,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get model => $state.composableBuilder(
      column: $state.table.model,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get focalLength => $state.composableBuilder(
      column: $state.table.focalLength,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get focalMin => $state.composableBuilder(
      column: $state.table.focalMin,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get focalMax => $state.composableBuilder(
      column: $state.table.focalMax,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get minTStop => $state.composableBuilder(
      column: $state.table.minTStop,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get formatCoverage => $state.composableBuilder(
      column: $state.table.formatCoverage,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get notes => $state.composableBuilder(
      column: $state.table.notes,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$LightsTableCreateCompanionBuilder = LightsCompanion Function({
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
typedef $$LightsTableUpdateCompanionBuilder = LightsCompanion Function({
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

class $$LightsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LightsTable,
    Light,
    $$LightsTableFilterComposer,
    $$LightsTableOrderingComposer,
    $$LightsTableCreateCompanionBuilder,
    $$LightsTableUpdateCompanionBuilder> {
  $$LightsTableTableManager(_$AppDatabase db, $LightsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$LightsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$LightsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
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
          }) =>
              LightsCompanion(
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
          createCompanionCallback: ({
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
          }) =>
              LightsCompanion.insert(
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
        ));
}

class $$LightsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $LightsTable> {
  $$LightsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get brand => $state.composableBuilder(
      column: $state.table.brand,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get model => $state.composableBuilder(
      column: $state.table.model,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get lightType => $state.composableBuilder(
      column: $state.table.lightType,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get powerW => $state.composableBuilder(
      column: $state.table.powerW,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get colorTempMin => $state.composableBuilder(
      column: $state.table.colorTempMin,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get colorTempMax => $state.composableBuilder(
      column: $state.table.colorTempMax,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get isLukaCompatible => $state.composableBuilder(
      column: $state.table.isLukaCompatible,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get lukaFixtureId => $state.composableBuilder(
      column: $state.table.lukaFixtureId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get notes => $state.composableBuilder(
      column: $state.table.notes,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$LightsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $LightsTable> {
  $$LightsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get brand => $state.composableBuilder(
      column: $state.table.brand,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get model => $state.composableBuilder(
      column: $state.table.model,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get lightType => $state.composableBuilder(
      column: $state.table.lightType,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get powerW => $state.composableBuilder(
      column: $state.table.powerW,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get colorTempMin => $state.composableBuilder(
      column: $state.table.colorTempMin,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get colorTempMax => $state.composableBuilder(
      column: $state.table.colorTempMax,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get isLukaCompatible => $state.composableBuilder(
      column: $state.table.isLukaCompatible,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get lukaFixtureId => $state.composableBuilder(
      column: $state.table.lukaFixtureId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get notes => $state.composableBuilder(
      column: $state.table.notes,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$ProjectEquipmentTableCreateCompanionBuilder
    = ProjectEquipmentCompanion Function({
  Value<int> id,
  required int projectId,
  required String equipmentType,
  required int equipmentId,
  Value<String> source,
  Value<String> status,
  Value<String?> notes,
});
typedef $$ProjectEquipmentTableUpdateCompanionBuilder
    = ProjectEquipmentCompanion Function({
  Value<int> id,
  Value<int> projectId,
  Value<String> equipmentType,
  Value<int> equipmentId,
  Value<String> source,
  Value<String> status,
  Value<String?> notes,
});

class $$ProjectEquipmentTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ProjectEquipmentTable,
    ProjectEquipmentData,
    $$ProjectEquipmentTableFilterComposer,
    $$ProjectEquipmentTableOrderingComposer,
    $$ProjectEquipmentTableCreateCompanionBuilder,
    $$ProjectEquipmentTableUpdateCompanionBuilder> {
  $$ProjectEquipmentTableTableManager(
      _$AppDatabase db, $ProjectEquipmentTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$ProjectEquipmentTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$ProjectEquipmentTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> projectId = const Value.absent(),
            Value<String> equipmentType = const Value.absent(),
            Value<int> equipmentId = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> notes = const Value.absent(),
          }) =>
              ProjectEquipmentCompanion(
            id: id,
            projectId: projectId,
            equipmentType: equipmentType,
            equipmentId: equipmentId,
            source: source,
            status: status,
            notes: notes,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int projectId,
            required String equipmentType,
            required int equipmentId,
            Value<String> source = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> notes = const Value.absent(),
          }) =>
              ProjectEquipmentCompanion.insert(
            id: id,
            projectId: projectId,
            equipmentType: equipmentType,
            equipmentId: equipmentId,
            source: source,
            status: status,
            notes: notes,
          ),
        ));
}

class $$ProjectEquipmentTableFilterComposer
    extends FilterComposer<_$AppDatabase, $ProjectEquipmentTable> {
  $$ProjectEquipmentTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get equipmentType => $state.composableBuilder(
      column: $state.table.equipmentType,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get equipmentId => $state.composableBuilder(
      column: $state.table.equipmentId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get source => $state.composableBuilder(
      column: $state.table.source,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get status => $state.composableBuilder(
      column: $state.table.status,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get notes => $state.composableBuilder(
      column: $state.table.notes,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $state.db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$ProjectsTableFilterComposer(ComposerState(
                $state.db, $state.db.projects, joinBuilder, parentComposers)));
    return composer;
  }
}

class $$ProjectEquipmentTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $ProjectEquipmentTable> {
  $$ProjectEquipmentTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get equipmentType => $state.composableBuilder(
      column: $state.table.equipmentType,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get equipmentId => $state.composableBuilder(
      column: $state.table.equipmentId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get source => $state.composableBuilder(
      column: $state.table.source,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get status => $state.composableBuilder(
      column: $state.table.status,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get notes => $state.composableBuilder(
      column: $state.table.notes,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $state.db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$ProjectsTableOrderingComposer(ComposerState(
                $state.db, $state.db.projects, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$LookBiblesTableCreateCompanionBuilder = LookBiblesCompanion Function({
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
typedef $$LookBiblesTableUpdateCompanionBuilder = LookBiblesCompanion Function({
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

class $$LookBiblesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LookBiblesTable,
    LookBible,
    $$LookBiblesTableFilterComposer,
    $$LookBiblesTableOrderingComposer,
    $$LookBiblesTableCreateCompanionBuilder,
    $$LookBiblesTableUpdateCompanionBuilder> {
  $$LookBiblesTableTableManager(_$AppDatabase db, $LookBiblesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$LookBiblesTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$LookBiblesTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
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
          }) =>
              LookBiblesCompanion(
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
          createCompanionCallback: ({
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
          }) =>
              LookBiblesCompanion.insert(
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
        ));
}

class $$LookBiblesTableFilterComposer
    extends FilterComposer<_$AppDatabase, $LookBiblesTable> {
  $$LookBiblesTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get visualConcept => $state.composableBuilder(
      column: $state.table.visualConcept,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get colorPalette => $state.composableBuilder(
      column: $state.table.colorPalette,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get lutName => $state.composableBuilder(
      column: $state.table.lutName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get filmReferences => $state.composableBuilder(
      column: $state.table.filmReferences,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get lightingPhilosophy => $state.composableBuilder(
      column: $state.table.lightingPhilosophy,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get contrastStyle => $state.composableBuilder(
      column: $state.table.contrastStyle,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get actOneNotes => $state.composableBuilder(
      column: $state.table.actOneNotes,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get actTwoNotes => $state.composableBuilder(
      column: $state.table.actTwoNotes,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get actThreeNotes => $state.composableBuilder(
      column: $state.table.actThreeNotes,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get moodboardImages => $state.composableBuilder(
      column: $state.table.moodboardImages,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get updatedAt => $state.composableBuilder(
      column: $state.table.updatedAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $state.db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$ProjectsTableFilterComposer(ComposerState(
                $state.db, $state.db.projects, joinBuilder, parentComposers)));
    return composer;
  }
}

class $$LookBiblesTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $LookBiblesTable> {
  $$LookBiblesTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get visualConcept => $state.composableBuilder(
      column: $state.table.visualConcept,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get colorPalette => $state.composableBuilder(
      column: $state.table.colorPalette,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get lutName => $state.composableBuilder(
      column: $state.table.lutName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get filmReferences => $state.composableBuilder(
      column: $state.table.filmReferences,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get lightingPhilosophy => $state.composableBuilder(
      column: $state.table.lightingPhilosophy,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get contrastStyle => $state.composableBuilder(
      column: $state.table.contrastStyle,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get actOneNotes => $state.composableBuilder(
      column: $state.table.actOneNotes,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get actTwoNotes => $state.composableBuilder(
      column: $state.table.actTwoNotes,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get actThreeNotes => $state.composableBuilder(
      column: $state.table.actThreeNotes,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get moodboardImages => $state.composableBuilder(
      column: $state.table.moodboardImages,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get updatedAt => $state.composableBuilder(
      column: $state.table.updatedAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $state.db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$ProjectsTableOrderingComposer(ComposerState(
                $state.db, $state.db.projects, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$ProjectAnnotatedPdfsTableCreateCompanionBuilder
    = ProjectAnnotatedPdfsCompanion Function({
  Value<int> id,
  required int projectId,
  required String moduleType,
  required String pdfPath,
  Value<DateTime> importedAt,
});
typedef $$ProjectAnnotatedPdfsTableUpdateCompanionBuilder
    = ProjectAnnotatedPdfsCompanion Function({
  Value<int> id,
  Value<int> projectId,
  Value<String> moduleType,
  Value<String> pdfPath,
  Value<DateTime> importedAt,
});

class $$ProjectAnnotatedPdfsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ProjectAnnotatedPdfsTable,
    ProjectAnnotatedPdf,
    $$ProjectAnnotatedPdfsTableFilterComposer,
    $$ProjectAnnotatedPdfsTableOrderingComposer,
    $$ProjectAnnotatedPdfsTableCreateCompanionBuilder,
    $$ProjectAnnotatedPdfsTableUpdateCompanionBuilder> {
  $$ProjectAnnotatedPdfsTableTableManager(
      _$AppDatabase db, $ProjectAnnotatedPdfsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer: $$ProjectAnnotatedPdfsTableFilterComposer(
              ComposerState(db, table)),
          orderingComposer: $$ProjectAnnotatedPdfsTableOrderingComposer(
              ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> projectId = const Value.absent(),
            Value<String> moduleType = const Value.absent(),
            Value<String> pdfPath = const Value.absent(),
            Value<DateTime> importedAt = const Value.absent(),
          }) =>
              ProjectAnnotatedPdfsCompanion(
            id: id,
            projectId: projectId,
            moduleType: moduleType,
            pdfPath: pdfPath,
            importedAt: importedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int projectId,
            required String moduleType,
            required String pdfPath,
            Value<DateTime> importedAt = const Value.absent(),
          }) =>
              ProjectAnnotatedPdfsCompanion.insert(
            id: id,
            projectId: projectId,
            moduleType: moduleType,
            pdfPath: pdfPath,
            importedAt: importedAt,
          ),
        ));
}

class $$ProjectAnnotatedPdfsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $ProjectAnnotatedPdfsTable> {
  $$ProjectAnnotatedPdfsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get moduleType => $state.composableBuilder(
      column: $state.table.moduleType,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get pdfPath => $state.composableBuilder(
      column: $state.table.pdfPath,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get importedAt => $state.composableBuilder(
      column: $state.table.importedAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $state.db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$ProjectsTableFilterComposer(ComposerState(
                $state.db, $state.db.projects, joinBuilder, parentComposers)));
    return composer;
  }
}

class $$ProjectAnnotatedPdfsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $ProjectAnnotatedPdfsTable> {
  $$ProjectAnnotatedPdfsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get moduleType => $state.composableBuilder(
      column: $state.table.moduleType,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get pdfPath => $state.composableBuilder(
      column: $state.table.pdfPath,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get importedAt => $state.composableBuilder(
      column: $state.table.importedAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $state.db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$ProjectsTableOrderingComposer(ComposerState(
                $state.db, $state.db.projects, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$VisualBiblesTableCreateCompanionBuilder = VisualBiblesCompanion
    Function({
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
typedef $$VisualBiblesTableUpdateCompanionBuilder = VisualBiblesCompanion
    Function({
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

class $$VisualBiblesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $VisualBiblesTable,
    VisualBible,
    $$VisualBiblesTableFilterComposer,
    $$VisualBiblesTableOrderingComposer,
    $$VisualBiblesTableCreateCompanionBuilder,
    $$VisualBiblesTableUpdateCompanionBuilder> {
  $$VisualBiblesTableTableManager(_$AppDatabase db, $VisualBiblesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$VisualBiblesTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$VisualBiblesTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
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
          }) =>
              VisualBiblesCompanion(
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
          createCompanionCallback: ({
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
          }) =>
              VisualBiblesCompanion.insert(
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
        ));
}

class $$VisualBiblesTableFilterComposer
    extends FilterComposer<_$AppDatabase, $VisualBiblesTable> {
  $$VisualBiblesTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get visualConcept => $state.composableBuilder(
      column: $state.table.visualConcept,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get narrativeReferences => $state.composableBuilder(
      column: $state.table.narrativeReferences,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get lightingPhilosophy => $state.composableBuilder(
      column: $state.table.lightingPhilosophy,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get lightQuality => $state.composableBuilder(
      column: $state.table.lightQuality,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get contrastStyle => $state.composableBuilder(
      column: $state.table.contrastStyle,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get keyFillRatioDay => $state.composableBuilder(
      column: $state.table.keyFillRatioDay,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get keyFillRatioNight => $state.composableBuilder(
      column: $state.table.keyFillRatioNight,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get lightSource => $state.composableBuilder(
      column: $state.table.lightSource,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get cameraPhilosophy => $state.composableBuilder(
      column: $state.table.cameraPhilosophy,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get movementStyle => $state.composableBuilder(
      column: $state.table.movementStyle,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get preferredMovements => $state.composableBuilder(
      column: $state.table.preferredMovements,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get lensPhilosophy => $state.composableBuilder(
      column: $state.table.lensPhilosophy,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get opticType => $state.composableBuilder(
      column: $state.table.opticType,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get primaryFocalLengths => $state.composableBuilder(
      column: $state.table.primaryFocalLengths,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get aspectRatio => $state.composableBuilder(
      column: $state.table.aspectRatio,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get aspectRatioJustification =>
      $state.composableBuilder(
          column: $state.table.aspectRatioJustification,
          builder: (column, joinBuilders) =>
              ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get imageTexture => $state.composableBuilder(
      column: $state.table.imageTexture,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get grainLevel => $state.composableBuilder(
      column: $state.table.grainLevel,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get highlightBehavior => $state.composableBuilder(
      column: $state.table.highlightBehavior,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get shadowBehavior => $state.composableBuilder(
      column: $state.table.shadowBehavior,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get workingLutName => $state.composableBuilder(
      column: $state.table.workingLutName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get creativeLutName => $state.composableBuilder(
      column: $state.table.creativeLutName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get creativeLutDescription => $state.composableBuilder(
      column: $state.table.creativeLutDescription,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get updatedAt => $state.composableBuilder(
      column: $state.table.updatedAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $state.db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$ProjectsTableFilterComposer(ComposerState(
                $state.db, $state.db.projects, joinBuilder, parentComposers)));
    return composer;
  }

  $$LensesTableFilterComposer get primaryLensId {
    final $$LensesTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.primaryLensId,
        referencedTable: $state.db.lenses,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$LensesTableFilterComposer(
            ComposerState(
                $state.db, $state.db.lenses, joinBuilder, parentComposers)));
    return composer;
  }

  ComposableFilter visualBibleColorBlocksRefs(
      ComposableFilter Function($$VisualBibleColorBlocksTableFilterComposer f)
          f) {
    final $$VisualBibleColorBlocksTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.visualBibleColorBlocks,
            getReferencedColumn: (t) => t.bibleId,
            builder: (joinBuilder, parentComposers) =>
                $$VisualBibleColorBlocksTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.visualBibleColorBlocks,
                    joinBuilder,
                    parentComposers)));
    return f(composer);
  }

  ComposableFilter visualBibleLocationRefsRefs(
      ComposableFilter Function($$VisualBibleLocationRefsTableFilterComposer f)
          f) {
    final $$VisualBibleLocationRefsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.visualBibleLocationRefs,
            getReferencedColumn: (t) => t.bibleId,
            builder: (joinBuilder, parentComposers) =>
                $$VisualBibleLocationRefsTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.visualBibleLocationRefs,
                    joinBuilder,
                    parentComposers)));
    return f(composer);
  }

  ComposableFilter moodboardImagesRefs(
      ComposableFilter Function($$MoodboardImagesTableFilterComposer f) f) {
    final $$MoodboardImagesTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.moodboardImages,
            getReferencedColumn: (t) => t.bibleId,
            builder: (joinBuilder, parentComposers) =>
                $$MoodboardImagesTableFilterComposer(ComposerState($state.db,
                    $state.db.moodboardImages, joinBuilder, parentComposers)));
    return f(composer);
  }
}

class $$VisualBiblesTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $VisualBiblesTable> {
  $$VisualBiblesTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get visualConcept => $state.composableBuilder(
      column: $state.table.visualConcept,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get narrativeReferences => $state.composableBuilder(
      column: $state.table.narrativeReferences,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get lightingPhilosophy => $state.composableBuilder(
      column: $state.table.lightingPhilosophy,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get lightQuality => $state.composableBuilder(
      column: $state.table.lightQuality,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get contrastStyle => $state.composableBuilder(
      column: $state.table.contrastStyle,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get keyFillRatioDay => $state.composableBuilder(
      column: $state.table.keyFillRatioDay,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get keyFillRatioNight => $state.composableBuilder(
      column: $state.table.keyFillRatioNight,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get lightSource => $state.composableBuilder(
      column: $state.table.lightSource,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get cameraPhilosophy => $state.composableBuilder(
      column: $state.table.cameraPhilosophy,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get movementStyle => $state.composableBuilder(
      column: $state.table.movementStyle,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get preferredMovements => $state.composableBuilder(
      column: $state.table.preferredMovements,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get lensPhilosophy => $state.composableBuilder(
      column: $state.table.lensPhilosophy,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get opticType => $state.composableBuilder(
      column: $state.table.opticType,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get primaryFocalLengths => $state.composableBuilder(
      column: $state.table.primaryFocalLengths,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get aspectRatio => $state.composableBuilder(
      column: $state.table.aspectRatio,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get aspectRatioJustification =>
      $state.composableBuilder(
          column: $state.table.aspectRatioJustification,
          builder: (column, joinBuilders) =>
              ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get imageTexture => $state.composableBuilder(
      column: $state.table.imageTexture,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get grainLevel => $state.composableBuilder(
      column: $state.table.grainLevel,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get highlightBehavior => $state.composableBuilder(
      column: $state.table.highlightBehavior,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get shadowBehavior => $state.composableBuilder(
      column: $state.table.shadowBehavior,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get workingLutName => $state.composableBuilder(
      column: $state.table.workingLutName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get creativeLutName => $state.composableBuilder(
      column: $state.table.creativeLutName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get creativeLutDescription =>
      $state.composableBuilder(
          column: $state.table.creativeLutDescription,
          builder: (column, joinBuilders) =>
              ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get updatedAt => $state.composableBuilder(
      column: $state.table.updatedAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $state.db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$ProjectsTableOrderingComposer(ComposerState(
                $state.db, $state.db.projects, joinBuilder, parentComposers)));
    return composer;
  }

  $$LensesTableOrderingComposer get primaryLensId {
    final $$LensesTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.primaryLensId,
        referencedTable: $state.db.lenses,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$LensesTableOrderingComposer(ComposerState(
                $state.db, $state.db.lenses, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$VisualBibleColorBlocksTableCreateCompanionBuilder
    = VisualBibleColorBlocksCompanion Function({
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
typedef $$VisualBibleColorBlocksTableUpdateCompanionBuilder
    = VisualBibleColorBlocksCompanion Function({
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

class $$VisualBibleColorBlocksTableTableManager extends RootTableManager<
    _$AppDatabase,
    $VisualBibleColorBlocksTable,
    VisualBibleColorBlock,
    $$VisualBibleColorBlocksTableFilterComposer,
    $$VisualBibleColorBlocksTableOrderingComposer,
    $$VisualBibleColorBlocksTableCreateCompanionBuilder,
    $$VisualBibleColorBlocksTableUpdateCompanionBuilder> {
  $$VisualBibleColorBlocksTableTableManager(
      _$AppDatabase db, $VisualBibleColorBlocksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer: $$VisualBibleColorBlocksTableFilterComposer(
              ComposerState(db, table)),
          orderingComposer: $$VisualBibleColorBlocksTableOrderingComposer(
              ComposerState(db, table)),
          updateCompanionCallback: ({
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
          }) =>
              VisualBibleColorBlocksCompanion(
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
          createCompanionCallback: ({
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
          }) =>
              VisualBibleColorBlocksCompanion.insert(
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
        ));
}

class $$VisualBibleColorBlocksTableFilterComposer
    extends FilterComposer<_$AppDatabase, $VisualBibleColorBlocksTable> {
  $$VisualBibleColorBlocksTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get blockName => $state.composableBuilder(
      column: $state.table.blockName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get emotionalIntent => $state.composableBuilder(
      column: $state.table.emotionalIntent,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get dominantColors => $state.composableBuilder(
      column: $state.table.dominantColors,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get accentColors => $state.composableBuilder(
      column: $state.table.accentColors,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get prohibitedColors => $state.composableBuilder(
      column: $state.table.prohibitedColors,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get colorTempKelvin => $state.composableBuilder(
      column: $state.table.colorTempKelvin,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get referenceImages => $state.composableBuilder(
      column: $state.table.referenceImages,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get sortOrder => $state.composableBuilder(
      column: $state.table.sortOrder,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$VisualBiblesTableFilterComposer get bibleId {
    final $$VisualBiblesTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bibleId,
        referencedTable: $state.db.visualBibles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$VisualBiblesTableFilterComposer(ComposerState($state.db,
                $state.db.visualBibles, joinBuilder, parentComposers)));
    return composer;
  }
}

class $$VisualBibleColorBlocksTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $VisualBibleColorBlocksTable> {
  $$VisualBibleColorBlocksTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get blockName => $state.composableBuilder(
      column: $state.table.blockName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get emotionalIntent => $state.composableBuilder(
      column: $state.table.emotionalIntent,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get dominantColors => $state.composableBuilder(
      column: $state.table.dominantColors,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get accentColors => $state.composableBuilder(
      column: $state.table.accentColors,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get prohibitedColors => $state.composableBuilder(
      column: $state.table.prohibitedColors,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get colorTempKelvin => $state.composableBuilder(
      column: $state.table.colorTempKelvin,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get referenceImages => $state.composableBuilder(
      column: $state.table.referenceImages,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get sortOrder => $state.composableBuilder(
      column: $state.table.sortOrder,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$VisualBiblesTableOrderingComposer get bibleId {
    final $$VisualBiblesTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bibleId,
        referencedTable: $state.db.visualBibles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$VisualBiblesTableOrderingComposer(ComposerState($state.db,
                $state.db.visualBibles, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$VisualBibleLocationRefsTableCreateCompanionBuilder
    = VisualBibleLocationRefsCompanion Function({
  Value<int> id,
  required int bibleId,
  required String locationName,
  Value<String?> lightingNote,
  Value<String?> colorNote,
  Value<String?> referenceImages,
  Value<String?> linkedShotIds,
});
typedef $$VisualBibleLocationRefsTableUpdateCompanionBuilder
    = VisualBibleLocationRefsCompanion Function({
  Value<int> id,
  Value<int> bibleId,
  Value<String> locationName,
  Value<String?> lightingNote,
  Value<String?> colorNote,
  Value<String?> referenceImages,
  Value<String?> linkedShotIds,
});

class $$VisualBibleLocationRefsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $VisualBibleLocationRefsTable,
    VisualBibleLocationRef,
    $$VisualBibleLocationRefsTableFilterComposer,
    $$VisualBibleLocationRefsTableOrderingComposer,
    $$VisualBibleLocationRefsTableCreateCompanionBuilder,
    $$VisualBibleLocationRefsTableUpdateCompanionBuilder> {
  $$VisualBibleLocationRefsTableTableManager(
      _$AppDatabase db, $VisualBibleLocationRefsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer: $$VisualBibleLocationRefsTableFilterComposer(
              ComposerState(db, table)),
          orderingComposer: $$VisualBibleLocationRefsTableOrderingComposer(
              ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> bibleId = const Value.absent(),
            Value<String> locationName = const Value.absent(),
            Value<String?> lightingNote = const Value.absent(),
            Value<String?> colorNote = const Value.absent(),
            Value<String?> referenceImages = const Value.absent(),
            Value<String?> linkedShotIds = const Value.absent(),
          }) =>
              VisualBibleLocationRefsCompanion(
            id: id,
            bibleId: bibleId,
            locationName: locationName,
            lightingNote: lightingNote,
            colorNote: colorNote,
            referenceImages: referenceImages,
            linkedShotIds: linkedShotIds,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int bibleId,
            required String locationName,
            Value<String?> lightingNote = const Value.absent(),
            Value<String?> colorNote = const Value.absent(),
            Value<String?> referenceImages = const Value.absent(),
            Value<String?> linkedShotIds = const Value.absent(),
          }) =>
              VisualBibleLocationRefsCompanion.insert(
            id: id,
            bibleId: bibleId,
            locationName: locationName,
            lightingNote: lightingNote,
            colorNote: colorNote,
            referenceImages: referenceImages,
            linkedShotIds: linkedShotIds,
          ),
        ));
}

class $$VisualBibleLocationRefsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $VisualBibleLocationRefsTable> {
  $$VisualBibleLocationRefsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get locationName => $state.composableBuilder(
      column: $state.table.locationName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get lightingNote => $state.composableBuilder(
      column: $state.table.lightingNote,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get colorNote => $state.composableBuilder(
      column: $state.table.colorNote,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get referenceImages => $state.composableBuilder(
      column: $state.table.referenceImages,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get linkedShotIds => $state.composableBuilder(
      column: $state.table.linkedShotIds,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$VisualBiblesTableFilterComposer get bibleId {
    final $$VisualBiblesTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bibleId,
        referencedTable: $state.db.visualBibles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$VisualBiblesTableFilterComposer(ComposerState($state.db,
                $state.db.visualBibles, joinBuilder, parentComposers)));
    return composer;
  }
}

class $$VisualBibleLocationRefsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $VisualBibleLocationRefsTable> {
  $$VisualBibleLocationRefsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get locationName => $state.composableBuilder(
      column: $state.table.locationName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get lightingNote => $state.composableBuilder(
      column: $state.table.lightingNote,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get colorNote => $state.composableBuilder(
      column: $state.table.colorNote,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get referenceImages => $state.composableBuilder(
      column: $state.table.referenceImages,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get linkedShotIds => $state.composableBuilder(
      column: $state.table.linkedShotIds,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$VisualBiblesTableOrderingComposer get bibleId {
    final $$VisualBiblesTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bibleId,
        referencedTable: $state.db.visualBibles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$VisualBiblesTableOrderingComposer(ComposerState($state.db,
                $state.db.visualBibles, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$MoodboardImagesTableCreateCompanionBuilder = MoodboardImagesCompanion
    Function({
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
typedef $$MoodboardImagesTableUpdateCompanionBuilder = MoodboardImagesCompanion
    Function({
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

class $$MoodboardImagesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MoodboardImagesTable,
    MoodboardImage,
    $$MoodboardImagesTableFilterComposer,
    $$MoodboardImagesTableOrderingComposer,
    $$MoodboardImagesTableCreateCompanionBuilder,
    $$MoodboardImagesTableUpdateCompanionBuilder> {
  $$MoodboardImagesTableTableManager(
      _$AppDatabase db, $MoodboardImagesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$MoodboardImagesTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$MoodboardImagesTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
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
          }) =>
              MoodboardImagesCompanion(
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
          createCompanionCallback: ({
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
          }) =>
              MoodboardImagesCompanion.insert(
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
        ));
}

class $$MoodboardImagesTableFilterComposer
    extends FilterComposer<_$AppDatabase, $MoodboardImagesTable> {
  $$MoodboardImagesTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get imagePath => $state.composableBuilder(
      column: $state.table.imagePath,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get source => $state.composableBuilder(
      column: $state.table.source,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get category => $state.composableBuilder(
      column: $state.table.category,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get caption => $state.composableBuilder(
      column: $state.table.caption,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get filmReference => $state.composableBuilder(
      column: $state.table.filmReference,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get linkedSceneId => $state.composableBuilder(
      column: $state.table.linkedSceneId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get linkedLocationName => $state.composableBuilder(
      column: $state.table.linkedLocationName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get sortOrder => $state.composableBuilder(
      column: $state.table.sortOrder,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $state.db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$ProjectsTableFilterComposer(ComposerState(
                $state.db, $state.db.projects, joinBuilder, parentComposers)));
    return composer;
  }

  $$VisualBiblesTableFilterComposer get bibleId {
    final $$VisualBiblesTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bibleId,
        referencedTable: $state.db.visualBibles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$VisualBiblesTableFilterComposer(ComposerState($state.db,
                $state.db.visualBibles, joinBuilder, parentComposers)));
    return composer;
  }
}

class $$MoodboardImagesTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $MoodboardImagesTable> {
  $$MoodboardImagesTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get imagePath => $state.composableBuilder(
      column: $state.table.imagePath,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get source => $state.composableBuilder(
      column: $state.table.source,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get category => $state.composableBuilder(
      column: $state.table.category,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get caption => $state.composableBuilder(
      column: $state.table.caption,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get filmReference => $state.composableBuilder(
      column: $state.table.filmReference,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get linkedSceneId => $state.composableBuilder(
      column: $state.table.linkedSceneId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get linkedLocationName => $state.composableBuilder(
      column: $state.table.linkedLocationName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get sortOrder => $state.composableBuilder(
      column: $state.table.sortOrder,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $state.db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$ProjectsTableOrderingComposer(ComposerState(
                $state.db, $state.db.projects, joinBuilder, parentComposers)));
    return composer;
  }

  $$VisualBiblesTableOrderingComposer get bibleId {
    final $$VisualBiblesTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bibleId,
        referencedTable: $state.db.visualBibles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$VisualBiblesTableOrderingComposer(ComposerState($state.db,
                $state.db.visualBibles, joinBuilder, parentComposers)));
    return composer;
  }
}

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
          _db, _db.visualBibleColorBlocks);
  $$VisualBibleLocationRefsTableTableManager get visualBibleLocationRefs =>
      $$VisualBibleLocationRefsTableTableManager(
          _db, _db.visualBibleLocationRefs);
  $$MoodboardImagesTableTableManager get moodboardImages =>
      $$MoodboardImagesTableTableManager(_db, _db.moodboardImages);
}
