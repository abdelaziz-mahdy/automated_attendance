// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $DBTrackedFacesTable extends DBTrackedFaces
    with TableInfo<$DBTrackedFacesTable, DBTrackedFace> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DBTrackedFacesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _featuresMeta =
      const VerificationMeta('features');
  @override
  late final GeneratedColumn<Uint8List> features = GeneratedColumn<Uint8List>(
      'features', aliasedName, false,
      type: DriftSqlType.blob, requiredDuringInsert: true);
  static const VerificationMeta _thumbnailMeta =
      const VerificationMeta('thumbnail');
  @override
  late final GeneratedColumn<Uint8List> thumbnail = GeneratedColumn<Uint8List>(
      'thumbnail', aliasedName, true,
      type: DriftSqlType.blob, requiredDuringInsert: false);
  static const VerificationMeta _firstSeenMeta =
      const VerificationMeta('firstSeen');
  @override
  late final GeneratedColumn<DateTime> firstSeen = GeneratedColumn<DateTime>(
      'first_seen', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _lastSeenMeta =
      const VerificationMeta('lastSeen');
  @override
  late final GeneratedColumn<DateTime> lastSeen = GeneratedColumn<DateTime>(
      'last_seen', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _lastSeenProviderMeta =
      const VerificationMeta('lastSeenProvider');
  @override
  late final GeneratedColumn<String> lastSeenProvider = GeneratedColumn<String>(
      'last_seen_provider', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, features, thumbnail, firstSeen, lastSeen, lastSeenProvider];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'd_b_tracked_faces';
  @override
  VerificationContext validateIntegrity(Insertable<DBTrackedFace> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    }
    if (data.containsKey('features')) {
      context.handle(_featuresMeta,
          features.isAcceptableOrUnknown(data['features']!, _featuresMeta));
    } else if (isInserting) {
      context.missing(_featuresMeta);
    }
    if (data.containsKey('thumbnail')) {
      context.handle(_thumbnailMeta,
          thumbnail.isAcceptableOrUnknown(data['thumbnail']!, _thumbnailMeta));
    }
    if (data.containsKey('first_seen')) {
      context.handle(_firstSeenMeta,
          firstSeen.isAcceptableOrUnknown(data['first_seen']!, _firstSeenMeta));
    }
    if (data.containsKey('last_seen')) {
      context.handle(_lastSeenMeta,
          lastSeen.isAcceptableOrUnknown(data['last_seen']!, _lastSeenMeta));
    }
    if (data.containsKey('last_seen_provider')) {
      context.handle(
          _lastSeenProviderMeta,
          lastSeenProvider.isAcceptableOrUnknown(
              data['last_seen_provider']!, _lastSeenProviderMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DBTrackedFace map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DBTrackedFace(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name']),
      features: attachedDatabase.typeMapping
          .read(DriftSqlType.blob, data['${effectivePrefix}features'])!,
      thumbnail: attachedDatabase.typeMapping
          .read(DriftSqlType.blob, data['${effectivePrefix}thumbnail']),
      firstSeen: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}first_seen']),
      lastSeen: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_seen']),
      lastSeenProvider: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}last_seen_provider']),
    );
  }

  @override
  $DBTrackedFacesTable createAlias(String alias) {
    return $DBTrackedFacesTable(attachedDatabase, alias);
  }
}

class DBTrackedFace extends DataClass implements Insertable<DBTrackedFace> {
  final String id;
  final String? name;
  final Uint8List features;
  final Uint8List? thumbnail;
  final DateTime? firstSeen;
  final DateTime? lastSeen;
  final String? lastSeenProvider;
  const DBTrackedFace(
      {required this.id,
      this.name,
      required this.features,
      this.thumbnail,
      this.firstSeen,
      this.lastSeen,
      this.lastSeenProvider});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    map['features'] = Variable<Uint8List>(features);
    if (!nullToAbsent || thumbnail != null) {
      map['thumbnail'] = Variable<Uint8List>(thumbnail);
    }
    if (!nullToAbsent || firstSeen != null) {
      map['first_seen'] = Variable<DateTime>(firstSeen);
    }
    if (!nullToAbsent || lastSeen != null) {
      map['last_seen'] = Variable<DateTime>(lastSeen);
    }
    if (!nullToAbsent || lastSeenProvider != null) {
      map['last_seen_provider'] = Variable<String>(lastSeenProvider);
    }
    return map;
  }

  DBTrackedFacesCompanion toCompanion(bool nullToAbsent) {
    return DBTrackedFacesCompanion(
      id: Value(id),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      features: Value(features),
      thumbnail: thumbnail == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnail),
      firstSeen: firstSeen == null && nullToAbsent
          ? const Value.absent()
          : Value(firstSeen),
      lastSeen: lastSeen == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSeen),
      lastSeenProvider: lastSeenProvider == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSeenProvider),
    );
  }

  factory DBTrackedFace.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DBTrackedFace(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String?>(json['name']),
      features: serializer.fromJson<Uint8List>(json['features']),
      thumbnail: serializer.fromJson<Uint8List?>(json['thumbnail']),
      firstSeen: serializer.fromJson<DateTime?>(json['firstSeen']),
      lastSeen: serializer.fromJson<DateTime?>(json['lastSeen']),
      lastSeenProvider: serializer.fromJson<String?>(json['lastSeenProvider']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String?>(name),
      'features': serializer.toJson<Uint8List>(features),
      'thumbnail': serializer.toJson<Uint8List?>(thumbnail),
      'firstSeen': serializer.toJson<DateTime?>(firstSeen),
      'lastSeen': serializer.toJson<DateTime?>(lastSeen),
      'lastSeenProvider': serializer.toJson<String?>(lastSeenProvider),
    };
  }

  DBTrackedFace copyWith(
          {String? id,
          Value<String?> name = const Value.absent(),
          Uint8List? features,
          Value<Uint8List?> thumbnail = const Value.absent(),
          Value<DateTime?> firstSeen = const Value.absent(),
          Value<DateTime?> lastSeen = const Value.absent(),
          Value<String?> lastSeenProvider = const Value.absent()}) =>
      DBTrackedFace(
        id: id ?? this.id,
        name: name.present ? name.value : this.name,
        features: features ?? this.features,
        thumbnail: thumbnail.present ? thumbnail.value : this.thumbnail,
        firstSeen: firstSeen.present ? firstSeen.value : this.firstSeen,
        lastSeen: lastSeen.present ? lastSeen.value : this.lastSeen,
        lastSeenProvider: lastSeenProvider.present
            ? lastSeenProvider.value
            : this.lastSeenProvider,
      );
  DBTrackedFace copyWithCompanion(DBTrackedFacesCompanion data) {
    return DBTrackedFace(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      features: data.features.present ? data.features.value : this.features,
      thumbnail: data.thumbnail.present ? data.thumbnail.value : this.thumbnail,
      firstSeen: data.firstSeen.present ? data.firstSeen.value : this.firstSeen,
      lastSeen: data.lastSeen.present ? data.lastSeen.value : this.lastSeen,
      lastSeenProvider: data.lastSeenProvider.present
          ? data.lastSeenProvider.value
          : this.lastSeenProvider,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DBTrackedFace(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('features: $features, ')
          ..write('thumbnail: $thumbnail, ')
          ..write('firstSeen: $firstSeen, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('lastSeenProvider: $lastSeenProvider')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      name,
      $driftBlobEquality.hash(features),
      $driftBlobEquality.hash(thumbnail),
      firstSeen,
      lastSeen,
      lastSeenProvider);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DBTrackedFace &&
          other.id == this.id &&
          other.name == this.name &&
          $driftBlobEquality.equals(other.features, this.features) &&
          $driftBlobEquality.equals(other.thumbnail, this.thumbnail) &&
          other.firstSeen == this.firstSeen &&
          other.lastSeen == this.lastSeen &&
          other.lastSeenProvider == this.lastSeenProvider);
}

class DBTrackedFacesCompanion extends UpdateCompanion<DBTrackedFace> {
  final Value<String> id;
  final Value<String?> name;
  final Value<Uint8List> features;
  final Value<Uint8List?> thumbnail;
  final Value<DateTime?> firstSeen;
  final Value<DateTime?> lastSeen;
  final Value<String?> lastSeenProvider;
  final Value<int> rowid;
  const DBTrackedFacesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.features = const Value.absent(),
    this.thumbnail = const Value.absent(),
    this.firstSeen = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.lastSeenProvider = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DBTrackedFacesCompanion.insert({
    required String id,
    this.name = const Value.absent(),
    required Uint8List features,
    this.thumbnail = const Value.absent(),
    this.firstSeen = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.lastSeenProvider = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        features = Value(features);
  static Insertable<DBTrackedFace> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<Uint8List>? features,
    Expression<Uint8List>? thumbnail,
    Expression<DateTime>? firstSeen,
    Expression<DateTime>? lastSeen,
    Expression<String>? lastSeenProvider,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (features != null) 'features': features,
      if (thumbnail != null) 'thumbnail': thumbnail,
      if (firstSeen != null) 'first_seen': firstSeen,
      if (lastSeen != null) 'last_seen': lastSeen,
      if (lastSeenProvider != null) 'last_seen_provider': lastSeenProvider,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DBTrackedFacesCompanion copyWith(
      {Value<String>? id,
      Value<String?>? name,
      Value<Uint8List>? features,
      Value<Uint8List?>? thumbnail,
      Value<DateTime?>? firstSeen,
      Value<DateTime?>? lastSeen,
      Value<String?>? lastSeenProvider,
      Value<int>? rowid}) {
    return DBTrackedFacesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      features: features ?? this.features,
      thumbnail: thumbnail ?? this.thumbnail,
      firstSeen: firstSeen ?? this.firstSeen,
      lastSeen: lastSeen ?? this.lastSeen,
      lastSeenProvider: lastSeenProvider ?? this.lastSeenProvider,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (features.present) {
      map['features'] = Variable<Uint8List>(features.value);
    }
    if (thumbnail.present) {
      map['thumbnail'] = Variable<Uint8List>(thumbnail.value);
    }
    if (firstSeen.present) {
      map['first_seen'] = Variable<DateTime>(firstSeen.value);
    }
    if (lastSeen.present) {
      map['last_seen'] = Variable<DateTime>(lastSeen.value);
    }
    if (lastSeenProvider.present) {
      map['last_seen_provider'] = Variable<String>(lastSeenProvider.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DBTrackedFacesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('features: $features, ')
          ..write('thumbnail: $thumbnail, ')
          ..write('firstSeen: $firstSeen, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('lastSeenProvider: $lastSeenProvider, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DBMergedFacesTable extends DBMergedFaces
    with TableInfo<$DBMergedFacesTable, DBMergedFace> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DBMergedFacesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _targetIdMeta =
      const VerificationMeta('targetId');
  @override
  late final GeneratedColumn<String> targetId = GeneratedColumn<String>(
      'target_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES d_b_tracked_faces (id)'));
  static const VerificationMeta _sourceIdMeta =
      const VerificationMeta('sourceId');
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
      'source_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _featuresMeta =
      const VerificationMeta('features');
  @override
  late final GeneratedColumn<Uint8List> features = GeneratedColumn<Uint8List>(
      'features', aliasedName, false,
      type: DriftSqlType.blob, requiredDuringInsert: true);
  static const VerificationMeta _thumbnailMeta =
      const VerificationMeta('thumbnail');
  @override
  late final GeneratedColumn<Uint8List> thumbnail = GeneratedColumn<Uint8List>(
      'thumbnail', aliasedName, true,
      type: DriftSqlType.blob, requiredDuringInsert: false);
  static const VerificationMeta _firstSeenMeta =
      const VerificationMeta('firstSeen');
  @override
  late final GeneratedColumn<DateTime> firstSeen = GeneratedColumn<DateTime>(
      'first_seen', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _lastSeenMeta =
      const VerificationMeta('lastSeen');
  @override
  late final GeneratedColumn<DateTime> lastSeen = GeneratedColumn<DateTime>(
      'last_seen', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, targetId, sourceId, features, thumbnail, firstSeen, lastSeen];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'd_b_merged_faces';
  @override
  VerificationContext validateIntegrity(Insertable<DBMergedFace> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('target_id')) {
      context.handle(_targetIdMeta,
          targetId.isAcceptableOrUnknown(data['target_id']!, _targetIdMeta));
    } else if (isInserting) {
      context.missing(_targetIdMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(_sourceIdMeta,
          sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta));
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('features')) {
      context.handle(_featuresMeta,
          features.isAcceptableOrUnknown(data['features']!, _featuresMeta));
    } else if (isInserting) {
      context.missing(_featuresMeta);
    }
    if (data.containsKey('thumbnail')) {
      context.handle(_thumbnailMeta,
          thumbnail.isAcceptableOrUnknown(data['thumbnail']!, _thumbnailMeta));
    }
    if (data.containsKey('first_seen')) {
      context.handle(_firstSeenMeta,
          firstSeen.isAcceptableOrUnknown(data['first_seen']!, _firstSeenMeta));
    }
    if (data.containsKey('last_seen')) {
      context.handle(_lastSeenMeta,
          lastSeen.isAcceptableOrUnknown(data['last_seen']!, _lastSeenMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DBMergedFace map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DBMergedFace(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      targetId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}target_id'])!,
      sourceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_id'])!,
      features: attachedDatabase.typeMapping
          .read(DriftSqlType.blob, data['${effectivePrefix}features'])!,
      thumbnail: attachedDatabase.typeMapping
          .read(DriftSqlType.blob, data['${effectivePrefix}thumbnail']),
      firstSeen: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}first_seen']),
      lastSeen: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_seen']),
    );
  }

  @override
  $DBMergedFacesTable createAlias(String alias) {
    return $DBMergedFacesTable(attachedDatabase, alias);
  }
}

class DBMergedFace extends DataClass implements Insertable<DBMergedFace> {
  final String id;
  final String targetId;
  final String sourceId;

  /// features are list of doubles
  final Uint8List features;
  final Uint8List? thumbnail;
  final DateTime? firstSeen;
  final DateTime? lastSeen;
  const DBMergedFace(
      {required this.id,
      required this.targetId,
      required this.sourceId,
      required this.features,
      this.thumbnail,
      this.firstSeen,
      this.lastSeen});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['target_id'] = Variable<String>(targetId);
    map['source_id'] = Variable<String>(sourceId);
    map['features'] = Variable<Uint8List>(features);
    if (!nullToAbsent || thumbnail != null) {
      map['thumbnail'] = Variable<Uint8List>(thumbnail);
    }
    if (!nullToAbsent || firstSeen != null) {
      map['first_seen'] = Variable<DateTime>(firstSeen);
    }
    if (!nullToAbsent || lastSeen != null) {
      map['last_seen'] = Variable<DateTime>(lastSeen);
    }
    return map;
  }

  DBMergedFacesCompanion toCompanion(bool nullToAbsent) {
    return DBMergedFacesCompanion(
      id: Value(id),
      targetId: Value(targetId),
      sourceId: Value(sourceId),
      features: Value(features),
      thumbnail: thumbnail == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnail),
      firstSeen: firstSeen == null && nullToAbsent
          ? const Value.absent()
          : Value(firstSeen),
      lastSeen: lastSeen == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSeen),
    );
  }

  factory DBMergedFace.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DBMergedFace(
      id: serializer.fromJson<String>(json['id']),
      targetId: serializer.fromJson<String>(json['targetId']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      features: serializer.fromJson<Uint8List>(json['features']),
      thumbnail: serializer.fromJson<Uint8List?>(json['thumbnail']),
      firstSeen: serializer.fromJson<DateTime?>(json['firstSeen']),
      lastSeen: serializer.fromJson<DateTime?>(json['lastSeen']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'targetId': serializer.toJson<String>(targetId),
      'sourceId': serializer.toJson<String>(sourceId),
      'features': serializer.toJson<Uint8List>(features),
      'thumbnail': serializer.toJson<Uint8List?>(thumbnail),
      'firstSeen': serializer.toJson<DateTime?>(firstSeen),
      'lastSeen': serializer.toJson<DateTime?>(lastSeen),
    };
  }

  DBMergedFace copyWith(
          {String? id,
          String? targetId,
          String? sourceId,
          Uint8List? features,
          Value<Uint8List?> thumbnail = const Value.absent(),
          Value<DateTime?> firstSeen = const Value.absent(),
          Value<DateTime?> lastSeen = const Value.absent()}) =>
      DBMergedFace(
        id: id ?? this.id,
        targetId: targetId ?? this.targetId,
        sourceId: sourceId ?? this.sourceId,
        features: features ?? this.features,
        thumbnail: thumbnail.present ? thumbnail.value : this.thumbnail,
        firstSeen: firstSeen.present ? firstSeen.value : this.firstSeen,
        lastSeen: lastSeen.present ? lastSeen.value : this.lastSeen,
      );
  DBMergedFace copyWithCompanion(DBMergedFacesCompanion data) {
    return DBMergedFace(
      id: data.id.present ? data.id.value : this.id,
      targetId: data.targetId.present ? data.targetId.value : this.targetId,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      features: data.features.present ? data.features.value : this.features,
      thumbnail: data.thumbnail.present ? data.thumbnail.value : this.thumbnail,
      firstSeen: data.firstSeen.present ? data.firstSeen.value : this.firstSeen,
      lastSeen: data.lastSeen.present ? data.lastSeen.value : this.lastSeen,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DBMergedFace(')
          ..write('id: $id, ')
          ..write('targetId: $targetId, ')
          ..write('sourceId: $sourceId, ')
          ..write('features: $features, ')
          ..write('thumbnail: $thumbnail, ')
          ..write('firstSeen: $firstSeen, ')
          ..write('lastSeen: $lastSeen')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      targetId,
      sourceId,
      $driftBlobEquality.hash(features),
      $driftBlobEquality.hash(thumbnail),
      firstSeen,
      lastSeen);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DBMergedFace &&
          other.id == this.id &&
          other.targetId == this.targetId &&
          other.sourceId == this.sourceId &&
          $driftBlobEquality.equals(other.features, this.features) &&
          $driftBlobEquality.equals(other.thumbnail, this.thumbnail) &&
          other.firstSeen == this.firstSeen &&
          other.lastSeen == this.lastSeen);
}

class DBMergedFacesCompanion extends UpdateCompanion<DBMergedFace> {
  final Value<String> id;
  final Value<String> targetId;
  final Value<String> sourceId;
  final Value<Uint8List> features;
  final Value<Uint8List?> thumbnail;
  final Value<DateTime?> firstSeen;
  final Value<DateTime?> lastSeen;
  final Value<int> rowid;
  const DBMergedFacesCompanion({
    this.id = const Value.absent(),
    this.targetId = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.features = const Value.absent(),
    this.thumbnail = const Value.absent(),
    this.firstSeen = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DBMergedFacesCompanion.insert({
    required String id,
    required String targetId,
    required String sourceId,
    required Uint8List features,
    this.thumbnail = const Value.absent(),
    this.firstSeen = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        targetId = Value(targetId),
        sourceId = Value(sourceId),
        features = Value(features);
  static Insertable<DBMergedFace> custom({
    Expression<String>? id,
    Expression<String>? targetId,
    Expression<String>? sourceId,
    Expression<Uint8List>? features,
    Expression<Uint8List>? thumbnail,
    Expression<DateTime>? firstSeen,
    Expression<DateTime>? lastSeen,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (targetId != null) 'target_id': targetId,
      if (sourceId != null) 'source_id': sourceId,
      if (features != null) 'features': features,
      if (thumbnail != null) 'thumbnail': thumbnail,
      if (firstSeen != null) 'first_seen': firstSeen,
      if (lastSeen != null) 'last_seen': lastSeen,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DBMergedFacesCompanion copyWith(
      {Value<String>? id,
      Value<String>? targetId,
      Value<String>? sourceId,
      Value<Uint8List>? features,
      Value<Uint8List?>? thumbnail,
      Value<DateTime?>? firstSeen,
      Value<DateTime?>? lastSeen,
      Value<int>? rowid}) {
    return DBMergedFacesCompanion(
      id: id ?? this.id,
      targetId: targetId ?? this.targetId,
      sourceId: sourceId ?? this.sourceId,
      features: features ?? this.features,
      thumbnail: thumbnail ?? this.thumbnail,
      firstSeen: firstSeen ?? this.firstSeen,
      lastSeen: lastSeen ?? this.lastSeen,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (targetId.present) {
      map['target_id'] = Variable<String>(targetId.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (features.present) {
      map['features'] = Variable<Uint8List>(features.value);
    }
    if (thumbnail.present) {
      map['thumbnail'] = Variable<Uint8List>(thumbnail.value);
    }
    if (firstSeen.present) {
      map['first_seen'] = Variable<DateTime>(firstSeen.value);
    }
    if (lastSeen.present) {
      map['last_seen'] = Variable<DateTime>(lastSeen.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DBMergedFacesCompanion(')
          ..write('id: $id, ')
          ..write('targetId: $targetId, ')
          ..write('sourceId: $sourceId, ')
          ..write('features: $features, ')
          ..write('thumbnail: $thumbnail, ')
          ..write('firstSeen: $firstSeen, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DBVisitsTable extends DBVisits with TableInfo<$DBVisitsTable, DBVisit> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DBVisitsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _faceIdMeta = const VerificationMeta('faceId');
  @override
  late final GeneratedColumn<String> faceId = GeneratedColumn<String>(
      'face_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _entryTimeMeta =
      const VerificationMeta('entryTime');
  @override
  late final GeneratedColumn<DateTime> entryTime = GeneratedColumn<DateTime>(
      'entry_time', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _exitTimeMeta =
      const VerificationMeta('exitTime');
  @override
  late final GeneratedColumn<DateTime> exitTime = GeneratedColumn<DateTime>(
      'exit_time', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _providerIdMeta =
      const VerificationMeta('providerId');
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
      'provider_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _durationSecondsMeta =
      const VerificationMeta('durationSeconds');
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
      'duration_seconds', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, faceId, entryTime, exitTime, providerId, durationSeconds];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'd_b_visits';
  @override
  VerificationContext validateIntegrity(Insertable<DBVisit> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('face_id')) {
      context.handle(_faceIdMeta,
          faceId.isAcceptableOrUnknown(data['face_id']!, _faceIdMeta));
    }
    if (data.containsKey('entry_time')) {
      context.handle(_entryTimeMeta,
          entryTime.isAcceptableOrUnknown(data['entry_time']!, _entryTimeMeta));
    } else if (isInserting) {
      context.missing(_entryTimeMeta);
    }
    if (data.containsKey('exit_time')) {
      context.handle(_exitTimeMeta,
          exitTime.isAcceptableOrUnknown(data['exit_time']!, _exitTimeMeta));
    }
    if (data.containsKey('provider_id')) {
      context.handle(
          _providerIdMeta,
          providerId.isAcceptableOrUnknown(
              data['provider_id']!, _providerIdMeta));
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
          _durationSecondsMeta,
          durationSeconds.isAcceptableOrUnknown(
              data['duration_seconds']!, _durationSecondsMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DBVisit map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DBVisit(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      faceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}face_id']),
      entryTime: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}entry_time'])!,
      exitTime: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}exit_time']),
      providerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}provider_id'])!,
      durationSeconds: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_seconds']),
    );
  }

  @override
  $DBVisitsTable createAlias(String alias) {
    return $DBVisitsTable(attachedDatabase, alias);
  }
}

class DBVisit extends DataClass implements Insertable<DBVisit> {
  final String id;
  final String? faceId;
  final DateTime entryTime;
  final DateTime? exitTime;
  final String providerId;
  final int? durationSeconds;
  const DBVisit(
      {required this.id,
      this.faceId,
      required this.entryTime,
      this.exitTime,
      required this.providerId,
      this.durationSeconds});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || faceId != null) {
      map['face_id'] = Variable<String>(faceId);
    }
    map['entry_time'] = Variable<DateTime>(entryTime);
    if (!nullToAbsent || exitTime != null) {
      map['exit_time'] = Variable<DateTime>(exitTime);
    }
    map['provider_id'] = Variable<String>(providerId);
    if (!nullToAbsent || durationSeconds != null) {
      map['duration_seconds'] = Variable<int>(durationSeconds);
    }
    return map;
  }

  DBVisitsCompanion toCompanion(bool nullToAbsent) {
    return DBVisitsCompanion(
      id: Value(id),
      faceId:
          faceId == null && nullToAbsent ? const Value.absent() : Value(faceId),
      entryTime: Value(entryTime),
      exitTime: exitTime == null && nullToAbsent
          ? const Value.absent()
          : Value(exitTime),
      providerId: Value(providerId),
      durationSeconds: durationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSeconds),
    );
  }

  factory DBVisit.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DBVisit(
      id: serializer.fromJson<String>(json['id']),
      faceId: serializer.fromJson<String?>(json['faceId']),
      entryTime: serializer.fromJson<DateTime>(json['entryTime']),
      exitTime: serializer.fromJson<DateTime?>(json['exitTime']),
      providerId: serializer.fromJson<String>(json['providerId']),
      durationSeconds: serializer.fromJson<int?>(json['durationSeconds']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'faceId': serializer.toJson<String?>(faceId),
      'entryTime': serializer.toJson<DateTime>(entryTime),
      'exitTime': serializer.toJson<DateTime?>(exitTime),
      'providerId': serializer.toJson<String>(providerId),
      'durationSeconds': serializer.toJson<int?>(durationSeconds),
    };
  }

  DBVisit copyWith(
          {String? id,
          Value<String?> faceId = const Value.absent(),
          DateTime? entryTime,
          Value<DateTime?> exitTime = const Value.absent(),
          String? providerId,
          Value<int?> durationSeconds = const Value.absent()}) =>
      DBVisit(
        id: id ?? this.id,
        faceId: faceId.present ? faceId.value : this.faceId,
        entryTime: entryTime ?? this.entryTime,
        exitTime: exitTime.present ? exitTime.value : this.exitTime,
        providerId: providerId ?? this.providerId,
        durationSeconds: durationSeconds.present
            ? durationSeconds.value
            : this.durationSeconds,
      );
  DBVisit copyWithCompanion(DBVisitsCompanion data) {
    return DBVisit(
      id: data.id.present ? data.id.value : this.id,
      faceId: data.faceId.present ? data.faceId.value : this.faceId,
      entryTime: data.entryTime.present ? data.entryTime.value : this.entryTime,
      exitTime: data.exitTime.present ? data.exitTime.value : this.exitTime,
      providerId:
          data.providerId.present ? data.providerId.value : this.providerId,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DBVisit(')
          ..write('id: $id, ')
          ..write('faceId: $faceId, ')
          ..write('entryTime: $entryTime, ')
          ..write('exitTime: $exitTime, ')
          ..write('providerId: $providerId, ')
          ..write('durationSeconds: $durationSeconds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, faceId, entryTime, exitTime, providerId, durationSeconds);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DBVisit &&
          other.id == this.id &&
          other.faceId == this.faceId &&
          other.entryTime == this.entryTime &&
          other.exitTime == this.exitTime &&
          other.providerId == this.providerId &&
          other.durationSeconds == this.durationSeconds);
}

class DBVisitsCompanion extends UpdateCompanion<DBVisit> {
  final Value<String> id;
  final Value<String?> faceId;
  final Value<DateTime> entryTime;
  final Value<DateTime?> exitTime;
  final Value<String> providerId;
  final Value<int?> durationSeconds;
  final Value<int> rowid;
  const DBVisitsCompanion({
    this.id = const Value.absent(),
    this.faceId = const Value.absent(),
    this.entryTime = const Value.absent(),
    this.exitTime = const Value.absent(),
    this.providerId = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DBVisitsCompanion.insert({
    required String id,
    this.faceId = const Value.absent(),
    required DateTime entryTime,
    this.exitTime = const Value.absent(),
    required String providerId,
    this.durationSeconds = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        entryTime = Value(entryTime),
        providerId = Value(providerId);
  static Insertable<DBVisit> custom({
    Expression<String>? id,
    Expression<String>? faceId,
    Expression<DateTime>? entryTime,
    Expression<DateTime>? exitTime,
    Expression<String>? providerId,
    Expression<int>? durationSeconds,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (faceId != null) 'face_id': faceId,
      if (entryTime != null) 'entry_time': entryTime,
      if (exitTime != null) 'exit_time': exitTime,
      if (providerId != null) 'provider_id': providerId,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DBVisitsCompanion copyWith(
      {Value<String>? id,
      Value<String?>? faceId,
      Value<DateTime>? entryTime,
      Value<DateTime?>? exitTime,
      Value<String>? providerId,
      Value<int?>? durationSeconds,
      Value<int>? rowid}) {
    return DBVisitsCompanion(
      id: id ?? this.id,
      faceId: faceId ?? this.faceId,
      entryTime: entryTime ?? this.entryTime,
      exitTime: exitTime ?? this.exitTime,
      providerId: providerId ?? this.providerId,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (faceId.present) {
      map['face_id'] = Variable<String>(faceId.value);
    }
    if (entryTime.present) {
      map['entry_time'] = Variable<DateTime>(entryTime.value);
    }
    if (exitTime.present) {
      map['exit_time'] = Variable<DateTime>(exitTime.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DBVisitsCompanion(')
          ..write('id: $id, ')
          ..write('faceId: $faceId, ')
          ..write('entryTime: $entryTime, ')
          ..write('exitTime: $exitTime, ')
          ..write('providerId: $providerId, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DBExpectedAttendeesTable extends DBExpectedAttendees
    with TableInfo<$DBExpectedAttendeesTable, DBExpectedAttendee> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DBExpectedAttendeesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _faceIdMeta = const VerificationMeta('faceId');
  @override
  late final GeneratedColumn<String> faceId = GeneratedColumn<String>(
      'face_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES d_b_tracked_faces (id)'));
  @override
  List<GeneratedColumn> get $columns => [faceId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'd_b_expected_attendees';
  @override
  VerificationContext validateIntegrity(Insertable<DBExpectedAttendee> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('face_id')) {
      context.handle(_faceIdMeta,
          faceId.isAcceptableOrUnknown(data['face_id']!, _faceIdMeta));
    } else if (isInserting) {
      context.missing(_faceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {faceId};
  @override
  DBExpectedAttendee map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DBExpectedAttendee(
      faceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}face_id'])!,
    );
  }

  @override
  $DBExpectedAttendeesTable createAlias(String alias) {
    return $DBExpectedAttendeesTable(attachedDatabase, alias);
  }
}

class DBExpectedAttendee extends DataClass
    implements Insertable<DBExpectedAttendee> {
  final String faceId;
  const DBExpectedAttendee({required this.faceId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['face_id'] = Variable<String>(faceId);
    return map;
  }

  DBExpectedAttendeesCompanion toCompanion(bool nullToAbsent) {
    return DBExpectedAttendeesCompanion(
      faceId: Value(faceId),
    );
  }

  factory DBExpectedAttendee.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DBExpectedAttendee(
      faceId: serializer.fromJson<String>(json['faceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'faceId': serializer.toJson<String>(faceId),
    };
  }

  DBExpectedAttendee copyWith({String? faceId}) => DBExpectedAttendee(
        faceId: faceId ?? this.faceId,
      );
  DBExpectedAttendee copyWithCompanion(DBExpectedAttendeesCompanion data) {
    return DBExpectedAttendee(
      faceId: data.faceId.present ? data.faceId.value : this.faceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DBExpectedAttendee(')
          ..write('faceId: $faceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => faceId.hashCode;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DBExpectedAttendee && other.faceId == this.faceId);
}

class DBExpectedAttendeesCompanion extends UpdateCompanion<DBExpectedAttendee> {
  final Value<String> faceId;
  final Value<int> rowid;
  const DBExpectedAttendeesCompanion({
    this.faceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DBExpectedAttendeesCompanion.insert({
    required String faceId,
    this.rowid = const Value.absent(),
  }) : faceId = Value(faceId);
  static Insertable<DBExpectedAttendee> custom({
    Expression<String>? faceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (faceId != null) 'face_id': faceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DBExpectedAttendeesCompanion copyWith(
      {Value<String>? faceId, Value<int>? rowid}) {
    return DBExpectedAttendeesCompanion(
      faceId: faceId ?? this.faceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (faceId.present) {
      map['face_id'] = Variable<String>(faceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DBExpectedAttendeesCompanion(')
          ..write('faceId: $faceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$FacesDatabase extends GeneratedDatabase {
  _$FacesDatabase(QueryExecutor e) : super(e);
  $FacesDatabaseManager get managers => $FacesDatabaseManager(this);
  late final $DBTrackedFacesTable dBTrackedFaces = $DBTrackedFacesTable(this);
  late final $DBMergedFacesTable dBMergedFaces = $DBMergedFacesTable(this);
  late final $DBVisitsTable dBVisits = $DBVisitsTable(this);
  late final $DBExpectedAttendeesTable dBExpectedAttendees =
      $DBExpectedAttendeesTable(this);
  late final Index faceNameIdx = Index('face_name_idx',
      'CREATE INDEX face_name_idx ON d_b_tracked_faces (name)');
  late final Index targetIdIdx = Index('target_id_idx',
      'CREATE INDEX target_id_idx ON d_b_merged_faces (target_id)');
  late final Index sourceIdIdx = Index('source_id_idx',
      'CREATE INDEX source_id_idx ON d_b_merged_faces (source_id)');
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        dBTrackedFaces,
        dBMergedFaces,
        dBVisits,
        dBExpectedAttendees,
        faceNameIdx,
        targetIdIdx,
        sourceIdIdx
      ];
}

typedef $$DBTrackedFacesTableCreateCompanionBuilder = DBTrackedFacesCompanion
    Function({
  required String id,
  Value<String?> name,
  required Uint8List features,
  Value<Uint8List?> thumbnail,
  Value<DateTime?> firstSeen,
  Value<DateTime?> lastSeen,
  Value<String?> lastSeenProvider,
  Value<int> rowid,
});
typedef $$DBTrackedFacesTableUpdateCompanionBuilder = DBTrackedFacesCompanion
    Function({
  Value<String> id,
  Value<String?> name,
  Value<Uint8List> features,
  Value<Uint8List?> thumbnail,
  Value<DateTime?> firstSeen,
  Value<DateTime?> lastSeen,
  Value<String?> lastSeenProvider,
  Value<int> rowid,
});

final class $$DBTrackedFacesTableReferences extends BaseReferences<
    _$FacesDatabase, $DBTrackedFacesTable, DBTrackedFace> {
  $$DBTrackedFacesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$DBMergedFacesTable, List<DBMergedFace>>
      _dBMergedFacesRefsTable(_$FacesDatabase db) =>
          MultiTypedResultKey.fromTable(db.dBMergedFaces,
              aliasName: $_aliasNameGenerator(
                  db.dBTrackedFaces.id, db.dBMergedFaces.targetId));

  $$DBMergedFacesTableProcessedTableManager get dBMergedFacesRefs {
    final manager = $$DBMergedFacesTableTableManager($_db, $_db.dBMergedFaces)
        .filter((f) => f.targetId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_dBMergedFacesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$DBExpectedAttendeesTable,
      List<DBExpectedAttendee>> _dBExpectedAttendeesRefsTable(
          _$FacesDatabase db) =>
      MultiTypedResultKey.fromTable(db.dBExpectedAttendees,
          aliasName: $_aliasNameGenerator(
              db.dBTrackedFaces.id, db.dBExpectedAttendees.faceId));

  $$DBExpectedAttendeesTableProcessedTableManager get dBExpectedAttendeesRefs {
    final manager =
        $$DBExpectedAttendeesTableTableManager($_db, $_db.dBExpectedAttendees)
            .filter((f) => f.faceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_dBExpectedAttendeesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$DBTrackedFacesTableFilterComposer
    extends Composer<_$FacesDatabase, $DBTrackedFacesTable> {
  $$DBTrackedFacesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<Uint8List> get features => $composableBuilder(
      column: $table.features, builder: (column) => ColumnFilters(column));

  ColumnFilters<Uint8List> get thumbnail => $composableBuilder(
      column: $table.thumbnail, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get firstSeen => $composableBuilder(
      column: $table.firstSeen, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastSeen => $composableBuilder(
      column: $table.lastSeen, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastSeenProvider => $composableBuilder(
      column: $table.lastSeenProvider,
      builder: (column) => ColumnFilters(column));

  Expression<bool> dBMergedFacesRefs(
      Expression<bool> Function($$DBMergedFacesTableFilterComposer f) f) {
    final $$DBMergedFacesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.dBMergedFaces,
        getReferencedColumn: (t) => t.targetId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DBMergedFacesTableFilterComposer(
              $db: $db,
              $table: $db.dBMergedFaces,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> dBExpectedAttendeesRefs(
      Expression<bool> Function($$DBExpectedAttendeesTableFilterComposer f) f) {
    final $$DBExpectedAttendeesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.dBExpectedAttendees,
        getReferencedColumn: (t) => t.faceId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DBExpectedAttendeesTableFilterComposer(
              $db: $db,
              $table: $db.dBExpectedAttendees,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$DBTrackedFacesTableOrderingComposer
    extends Composer<_$FacesDatabase, $DBTrackedFacesTable> {
  $$DBTrackedFacesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<Uint8List> get features => $composableBuilder(
      column: $table.features, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<Uint8List> get thumbnail => $composableBuilder(
      column: $table.thumbnail, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get firstSeen => $composableBuilder(
      column: $table.firstSeen, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastSeen => $composableBuilder(
      column: $table.lastSeen, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastSeenProvider => $composableBuilder(
      column: $table.lastSeenProvider,
      builder: (column) => ColumnOrderings(column));
}

class $$DBTrackedFacesTableAnnotationComposer
    extends Composer<_$FacesDatabase, $DBTrackedFacesTable> {
  $$DBTrackedFacesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<Uint8List> get features =>
      $composableBuilder(column: $table.features, builder: (column) => column);

  GeneratedColumn<Uint8List> get thumbnail =>
      $composableBuilder(column: $table.thumbnail, builder: (column) => column);

  GeneratedColumn<DateTime> get firstSeen =>
      $composableBuilder(column: $table.firstSeen, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSeen =>
      $composableBuilder(column: $table.lastSeen, builder: (column) => column);

  GeneratedColumn<String> get lastSeenProvider => $composableBuilder(
      column: $table.lastSeenProvider, builder: (column) => column);

  Expression<T> dBMergedFacesRefs<T extends Object>(
      Expression<T> Function($$DBMergedFacesTableAnnotationComposer a) f) {
    final $$DBMergedFacesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.dBMergedFaces,
        getReferencedColumn: (t) => t.targetId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DBMergedFacesTableAnnotationComposer(
              $db: $db,
              $table: $db.dBMergedFaces,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> dBExpectedAttendeesRefs<T extends Object>(
      Expression<T> Function($$DBExpectedAttendeesTableAnnotationComposer a)
          f) {
    final $$DBExpectedAttendeesTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.dBExpectedAttendees,
            getReferencedColumn: (t) => t.faceId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$DBExpectedAttendeesTableAnnotationComposer(
                  $db: $db,
                  $table: $db.dBExpectedAttendees,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }
}

class $$DBTrackedFacesTableTableManager extends RootTableManager<
    _$FacesDatabase,
    $DBTrackedFacesTable,
    DBTrackedFace,
    $$DBTrackedFacesTableFilterComposer,
    $$DBTrackedFacesTableOrderingComposer,
    $$DBTrackedFacesTableAnnotationComposer,
    $$DBTrackedFacesTableCreateCompanionBuilder,
    $$DBTrackedFacesTableUpdateCompanionBuilder,
    (DBTrackedFace, $$DBTrackedFacesTableReferences),
    DBTrackedFace,
    PrefetchHooks Function(
        {bool dBMergedFacesRefs, bool dBExpectedAttendeesRefs})> {
  $$DBTrackedFacesTableTableManager(
      _$FacesDatabase db, $DBTrackedFacesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DBTrackedFacesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DBTrackedFacesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DBTrackedFacesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String?> name = const Value.absent(),
            Value<Uint8List> features = const Value.absent(),
            Value<Uint8List?> thumbnail = const Value.absent(),
            Value<DateTime?> firstSeen = const Value.absent(),
            Value<DateTime?> lastSeen = const Value.absent(),
            Value<String?> lastSeenProvider = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DBTrackedFacesCompanion(
            id: id,
            name: name,
            features: features,
            thumbnail: thumbnail,
            firstSeen: firstSeen,
            lastSeen: lastSeen,
            lastSeenProvider: lastSeenProvider,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String?> name = const Value.absent(),
            required Uint8List features,
            Value<Uint8List?> thumbnail = const Value.absent(),
            Value<DateTime?> firstSeen = const Value.absent(),
            Value<DateTime?> lastSeen = const Value.absent(),
            Value<String?> lastSeenProvider = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DBTrackedFacesCompanion.insert(
            id: id,
            name: name,
            features: features,
            thumbnail: thumbnail,
            firstSeen: firstSeen,
            lastSeen: lastSeen,
            lastSeenProvider: lastSeenProvider,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$DBTrackedFacesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {dBMergedFacesRefs = false, dBExpectedAttendeesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (dBMergedFacesRefs) db.dBMergedFaces,
                if (dBExpectedAttendeesRefs) db.dBExpectedAttendees
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (dBMergedFacesRefs)
                    await $_getPrefetchedData<DBTrackedFace, $DBTrackedFacesTable,
                            DBMergedFace>(
                        currentTable: table,
                        referencedTable: $$DBTrackedFacesTableReferences
                            ._dBMergedFacesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$DBTrackedFacesTableReferences(db, table, p0)
                                .dBMergedFacesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.targetId == item.id),
                        typedResults: items),
                  if (dBExpectedAttendeesRefs)
                    await $_getPrefetchedData<DBTrackedFace,
                            $DBTrackedFacesTable, DBExpectedAttendee>(
                        currentTable: table,
                        referencedTable: $$DBTrackedFacesTableReferences
                            ._dBExpectedAttendeesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$DBTrackedFacesTableReferences(db, table, p0)
                                .dBExpectedAttendeesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.faceId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$DBTrackedFacesTableProcessedTableManager = ProcessedTableManager<
    _$FacesDatabase,
    $DBTrackedFacesTable,
    DBTrackedFace,
    $$DBTrackedFacesTableFilterComposer,
    $$DBTrackedFacesTableOrderingComposer,
    $$DBTrackedFacesTableAnnotationComposer,
    $$DBTrackedFacesTableCreateCompanionBuilder,
    $$DBTrackedFacesTableUpdateCompanionBuilder,
    (DBTrackedFace, $$DBTrackedFacesTableReferences),
    DBTrackedFace,
    PrefetchHooks Function(
        {bool dBMergedFacesRefs, bool dBExpectedAttendeesRefs})>;
typedef $$DBMergedFacesTableCreateCompanionBuilder = DBMergedFacesCompanion
    Function({
  required String id,
  required String targetId,
  required String sourceId,
  required Uint8List features,
  Value<Uint8List?> thumbnail,
  Value<DateTime?> firstSeen,
  Value<DateTime?> lastSeen,
  Value<int> rowid,
});
typedef $$DBMergedFacesTableUpdateCompanionBuilder = DBMergedFacesCompanion
    Function({
  Value<String> id,
  Value<String> targetId,
  Value<String> sourceId,
  Value<Uint8List> features,
  Value<Uint8List?> thumbnail,
  Value<DateTime?> firstSeen,
  Value<DateTime?> lastSeen,
  Value<int> rowid,
});

final class $$DBMergedFacesTableReferences
    extends BaseReferences<_$FacesDatabase, $DBMergedFacesTable, DBMergedFace> {
  $$DBMergedFacesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $DBTrackedFacesTable _targetIdTable(_$FacesDatabase db) =>
      db.dBTrackedFaces.createAlias($_aliasNameGenerator(
          db.dBMergedFaces.targetId, db.dBTrackedFaces.id));

  $$DBTrackedFacesTableProcessedTableManager get targetId {
    final $_column = $_itemColumn<String>('target_id')!;

    final manager = $$DBTrackedFacesTableTableManager($_db, $_db.dBTrackedFaces)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_targetIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$DBMergedFacesTableFilterComposer
    extends Composer<_$FacesDatabase, $DBMergedFacesTable> {
  $$DBMergedFacesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceId => $composableBuilder(
      column: $table.sourceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<Uint8List> get features => $composableBuilder(
      column: $table.features, builder: (column) => ColumnFilters(column));

  ColumnFilters<Uint8List> get thumbnail => $composableBuilder(
      column: $table.thumbnail, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get firstSeen => $composableBuilder(
      column: $table.firstSeen, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastSeen => $composableBuilder(
      column: $table.lastSeen, builder: (column) => ColumnFilters(column));

  $$DBTrackedFacesTableFilterComposer get targetId {
    final $$DBTrackedFacesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.targetId,
        referencedTable: $db.dBTrackedFaces,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DBTrackedFacesTableFilterComposer(
              $db: $db,
              $table: $db.dBTrackedFaces,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$DBMergedFacesTableOrderingComposer
    extends Composer<_$FacesDatabase, $DBMergedFacesTable> {
  $$DBMergedFacesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceId => $composableBuilder(
      column: $table.sourceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<Uint8List> get features => $composableBuilder(
      column: $table.features, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<Uint8List> get thumbnail => $composableBuilder(
      column: $table.thumbnail, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get firstSeen => $composableBuilder(
      column: $table.firstSeen, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastSeen => $composableBuilder(
      column: $table.lastSeen, builder: (column) => ColumnOrderings(column));

  $$DBTrackedFacesTableOrderingComposer get targetId {
    final $$DBTrackedFacesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.targetId,
        referencedTable: $db.dBTrackedFaces,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DBTrackedFacesTableOrderingComposer(
              $db: $db,
              $table: $db.dBTrackedFaces,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$DBMergedFacesTableAnnotationComposer
    extends Composer<_$FacesDatabase, $DBMergedFacesTable> {
  $$DBMergedFacesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<Uint8List> get features =>
      $composableBuilder(column: $table.features, builder: (column) => column);

  GeneratedColumn<Uint8List> get thumbnail =>
      $composableBuilder(column: $table.thumbnail, builder: (column) => column);

  GeneratedColumn<DateTime> get firstSeen =>
      $composableBuilder(column: $table.firstSeen, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSeen =>
      $composableBuilder(column: $table.lastSeen, builder: (column) => column);

  $$DBTrackedFacesTableAnnotationComposer get targetId {
    final $$DBTrackedFacesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.targetId,
        referencedTable: $db.dBTrackedFaces,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DBTrackedFacesTableAnnotationComposer(
              $db: $db,
              $table: $db.dBTrackedFaces,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$DBMergedFacesTableTableManager extends RootTableManager<
    _$FacesDatabase,
    $DBMergedFacesTable,
    DBMergedFace,
    $$DBMergedFacesTableFilterComposer,
    $$DBMergedFacesTableOrderingComposer,
    $$DBMergedFacesTableAnnotationComposer,
    $$DBMergedFacesTableCreateCompanionBuilder,
    $$DBMergedFacesTableUpdateCompanionBuilder,
    (DBMergedFace, $$DBMergedFacesTableReferences),
    DBMergedFace,
    PrefetchHooks Function({bool targetId})> {
  $$DBMergedFacesTableTableManager(
      _$FacesDatabase db, $DBMergedFacesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DBMergedFacesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DBMergedFacesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DBMergedFacesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> targetId = const Value.absent(),
            Value<String> sourceId = const Value.absent(),
            Value<Uint8List> features = const Value.absent(),
            Value<Uint8List?> thumbnail = const Value.absent(),
            Value<DateTime?> firstSeen = const Value.absent(),
            Value<DateTime?> lastSeen = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DBMergedFacesCompanion(
            id: id,
            targetId: targetId,
            sourceId: sourceId,
            features: features,
            thumbnail: thumbnail,
            firstSeen: firstSeen,
            lastSeen: lastSeen,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String targetId,
            required String sourceId,
            required Uint8List features,
            Value<Uint8List?> thumbnail = const Value.absent(),
            Value<DateTime?> firstSeen = const Value.absent(),
            Value<DateTime?> lastSeen = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DBMergedFacesCompanion.insert(
            id: id,
            targetId: targetId,
            sourceId: sourceId,
            features: features,
            thumbnail: thumbnail,
            firstSeen: firstSeen,
            lastSeen: lastSeen,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$DBMergedFacesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({targetId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
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
                      dynamic>>(state) {
                if (targetId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.targetId,
                    referencedTable:
                        $$DBMergedFacesTableReferences._targetIdTable(db),
                    referencedColumn:
                        $$DBMergedFacesTableReferences._targetIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$DBMergedFacesTableProcessedTableManager = ProcessedTableManager<
    _$FacesDatabase,
    $DBMergedFacesTable,
    DBMergedFace,
    $$DBMergedFacesTableFilterComposer,
    $$DBMergedFacesTableOrderingComposer,
    $$DBMergedFacesTableAnnotationComposer,
    $$DBMergedFacesTableCreateCompanionBuilder,
    $$DBMergedFacesTableUpdateCompanionBuilder,
    (DBMergedFace, $$DBMergedFacesTableReferences),
    DBMergedFace,
    PrefetchHooks Function({bool targetId})>;
typedef $$DBVisitsTableCreateCompanionBuilder = DBVisitsCompanion Function({
  required String id,
  Value<String?> faceId,
  required DateTime entryTime,
  Value<DateTime?> exitTime,
  required String providerId,
  Value<int?> durationSeconds,
  Value<int> rowid,
});
typedef $$DBVisitsTableUpdateCompanionBuilder = DBVisitsCompanion Function({
  Value<String> id,
  Value<String?> faceId,
  Value<DateTime> entryTime,
  Value<DateTime?> exitTime,
  Value<String> providerId,
  Value<int?> durationSeconds,
  Value<int> rowid,
});

class $$DBVisitsTableFilterComposer
    extends Composer<_$FacesDatabase, $DBVisitsTable> {
  $$DBVisitsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get faceId => $composableBuilder(
      column: $table.faceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get entryTime => $composableBuilder(
      column: $table.entryTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get exitTime => $composableBuilder(
      column: $table.exitTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get providerId => $composableBuilder(
      column: $table.providerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds,
      builder: (column) => ColumnFilters(column));
}

class $$DBVisitsTableOrderingComposer
    extends Composer<_$FacesDatabase, $DBVisitsTable> {
  $$DBVisitsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get faceId => $composableBuilder(
      column: $table.faceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get entryTime => $composableBuilder(
      column: $table.entryTime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get exitTime => $composableBuilder(
      column: $table.exitTime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get providerId => $composableBuilder(
      column: $table.providerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds,
      builder: (column) => ColumnOrderings(column));
}

class $$DBVisitsTableAnnotationComposer
    extends Composer<_$FacesDatabase, $DBVisitsTable> {
  $$DBVisitsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get faceId =>
      $composableBuilder(column: $table.faceId, builder: (column) => column);

  GeneratedColumn<DateTime> get entryTime =>
      $composableBuilder(column: $table.entryTime, builder: (column) => column);

  GeneratedColumn<DateTime> get exitTime =>
      $composableBuilder(column: $table.exitTime, builder: (column) => column);

  GeneratedColumn<String> get providerId => $composableBuilder(
      column: $table.providerId, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds, builder: (column) => column);
}

class $$DBVisitsTableTableManager extends RootTableManager<
    _$FacesDatabase,
    $DBVisitsTable,
    DBVisit,
    $$DBVisitsTableFilterComposer,
    $$DBVisitsTableOrderingComposer,
    $$DBVisitsTableAnnotationComposer,
    $$DBVisitsTableCreateCompanionBuilder,
    $$DBVisitsTableUpdateCompanionBuilder,
    (DBVisit, BaseReferences<_$FacesDatabase, $DBVisitsTable, DBVisit>),
    DBVisit,
    PrefetchHooks Function()> {
  $$DBVisitsTableTableManager(_$FacesDatabase db, $DBVisitsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DBVisitsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DBVisitsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DBVisitsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String?> faceId = const Value.absent(),
            Value<DateTime> entryTime = const Value.absent(),
            Value<DateTime?> exitTime = const Value.absent(),
            Value<String> providerId = const Value.absent(),
            Value<int?> durationSeconds = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DBVisitsCompanion(
            id: id,
            faceId: faceId,
            entryTime: entryTime,
            exitTime: exitTime,
            providerId: providerId,
            durationSeconds: durationSeconds,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String?> faceId = const Value.absent(),
            required DateTime entryTime,
            Value<DateTime?> exitTime = const Value.absent(),
            required String providerId,
            Value<int?> durationSeconds = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DBVisitsCompanion.insert(
            id: id,
            faceId: faceId,
            entryTime: entryTime,
            exitTime: exitTime,
            providerId: providerId,
            durationSeconds: durationSeconds,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DBVisitsTableProcessedTableManager = ProcessedTableManager<
    _$FacesDatabase,
    $DBVisitsTable,
    DBVisit,
    $$DBVisitsTableFilterComposer,
    $$DBVisitsTableOrderingComposer,
    $$DBVisitsTableAnnotationComposer,
    $$DBVisitsTableCreateCompanionBuilder,
    $$DBVisitsTableUpdateCompanionBuilder,
    (DBVisit, BaseReferences<_$FacesDatabase, $DBVisitsTable, DBVisit>),
    DBVisit,
    PrefetchHooks Function()>;
typedef $$DBExpectedAttendeesTableCreateCompanionBuilder
    = DBExpectedAttendeesCompanion Function({
  required String faceId,
  Value<int> rowid,
});
typedef $$DBExpectedAttendeesTableUpdateCompanionBuilder
    = DBExpectedAttendeesCompanion Function({
  Value<String> faceId,
  Value<int> rowid,
});

final class $$DBExpectedAttendeesTableReferences extends BaseReferences<
    _$FacesDatabase, $DBExpectedAttendeesTable, DBExpectedAttendee> {
  $$DBExpectedAttendeesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $DBTrackedFacesTable _faceIdTable(_$FacesDatabase db) =>
      db.dBTrackedFaces.createAlias($_aliasNameGenerator(
          db.dBExpectedAttendees.faceId, db.dBTrackedFaces.id));

  $$DBTrackedFacesTableProcessedTableManager get faceId {
    final $_column = $_itemColumn<String>('face_id')!;

    final manager = $$DBTrackedFacesTableTableManager($_db, $_db.dBTrackedFaces)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_faceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$DBExpectedAttendeesTableFilterComposer
    extends Composer<_$FacesDatabase, $DBExpectedAttendeesTable> {
  $$DBExpectedAttendeesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$DBTrackedFacesTableFilterComposer get faceId {
    final $$DBTrackedFacesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.faceId,
        referencedTable: $db.dBTrackedFaces,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DBTrackedFacesTableFilterComposer(
              $db: $db,
              $table: $db.dBTrackedFaces,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$DBExpectedAttendeesTableOrderingComposer
    extends Composer<_$FacesDatabase, $DBExpectedAttendeesTable> {
  $$DBExpectedAttendeesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$DBTrackedFacesTableOrderingComposer get faceId {
    final $$DBTrackedFacesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.faceId,
        referencedTable: $db.dBTrackedFaces,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DBTrackedFacesTableOrderingComposer(
              $db: $db,
              $table: $db.dBTrackedFaces,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$DBExpectedAttendeesTableAnnotationComposer
    extends Composer<_$FacesDatabase, $DBExpectedAttendeesTable> {
  $$DBExpectedAttendeesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$DBTrackedFacesTableAnnotationComposer get faceId {
    final $$DBTrackedFacesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.faceId,
        referencedTable: $db.dBTrackedFaces,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DBTrackedFacesTableAnnotationComposer(
              $db: $db,
              $table: $db.dBTrackedFaces,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$DBExpectedAttendeesTableTableManager extends RootTableManager<
    _$FacesDatabase,
    $DBExpectedAttendeesTable,
    DBExpectedAttendee,
    $$DBExpectedAttendeesTableFilterComposer,
    $$DBExpectedAttendeesTableOrderingComposer,
    $$DBExpectedAttendeesTableAnnotationComposer,
    $$DBExpectedAttendeesTableCreateCompanionBuilder,
    $$DBExpectedAttendeesTableUpdateCompanionBuilder,
    (DBExpectedAttendee, $$DBExpectedAttendeesTableReferences),
    DBExpectedAttendee,
    PrefetchHooks Function({bool faceId})> {
  $$DBExpectedAttendeesTableTableManager(
      _$FacesDatabase db, $DBExpectedAttendeesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DBExpectedAttendeesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DBExpectedAttendeesTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DBExpectedAttendeesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> faceId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DBExpectedAttendeesCompanion(
            faceId: faceId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String faceId,
            Value<int> rowid = const Value.absent(),
          }) =>
              DBExpectedAttendeesCompanion.insert(
            faceId: faceId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$DBExpectedAttendeesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({faceId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
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
                      dynamic>>(state) {
                if (faceId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.faceId,
                    referencedTable:
                        $$DBExpectedAttendeesTableReferences._faceIdTable(db),
                    referencedColumn: $$DBExpectedAttendeesTableReferences
                        ._faceIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$DBExpectedAttendeesTableProcessedTableManager = ProcessedTableManager<
    _$FacesDatabase,
    $DBExpectedAttendeesTable,
    DBExpectedAttendee,
    $$DBExpectedAttendeesTableFilterComposer,
    $$DBExpectedAttendeesTableOrderingComposer,
    $$DBExpectedAttendeesTableAnnotationComposer,
    $$DBExpectedAttendeesTableCreateCompanionBuilder,
    $$DBExpectedAttendeesTableUpdateCompanionBuilder,
    (DBExpectedAttendee, $$DBExpectedAttendeesTableReferences),
    DBExpectedAttendee,
    PrefetchHooks Function({bool faceId})>;

class $FacesDatabaseManager {
  final _$FacesDatabase _db;
  $FacesDatabaseManager(this._db);
  $$DBTrackedFacesTableTableManager get dBTrackedFaces =>
      $$DBTrackedFacesTableTableManager(_db, _db.dBTrackedFaces);
  $$DBMergedFacesTableTableManager get dBMergedFaces =>
      $$DBMergedFacesTableTableManager(_db, _db.dBMergedFaces);
  $$DBVisitsTableTableManager get dBVisits =>
      $$DBVisitsTableTableManager(_db, _db.dBVisits);
  $$DBExpectedAttendeesTableTableManager get dBExpectedAttendees =>
      $$DBExpectedAttendeesTableTableManager(_db, _db.dBExpectedAttendees);
}
