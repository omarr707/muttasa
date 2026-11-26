// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $KvEntriesTable extends KvEntries
    with TableInfo<$KvEntriesTable, KvEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KvEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'kv_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<KvEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  KvEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KvEntry(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $KvEntriesTable createAlias(String alias) {
    return $KvEntriesTable(attachedDatabase, alias);
  }
}

class KvEntry extends DataClass implements Insertable<KvEntry> {
  final String key;
  final String value;
  final int updatedAt;
  const KvEntry({
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  KvEntriesCompanion toCompanion(bool nullToAbsent) {
    return KvEntriesCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory KvEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KvEntry(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  KvEntry copyWith({String? key, String? value, int? updatedAt}) => KvEntry(
    key: key ?? this.key,
    value: value ?? this.value,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  KvEntry copyWithCompanion(KvEntriesCompanion data) {
    return KvEntry(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KvEntry(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KvEntry &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class KvEntriesCompanion extends UpdateCompanion<KvEntry> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const KvEntriesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KvEntriesCompanion.insert({
    required String key,
    required String value,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value),
       updatedAt = Value(updatedAt);
  static Insertable<KvEntry> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KvEntriesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return KvEntriesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KvEntriesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RuleRowsTable extends RuleRows with TableInfo<$RuleRowsTable, RuleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RuleRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ruleKeyMeta = const VerificationMeta(
    'ruleKey',
  );
  @override
  late final GeneratedColumn<String> ruleKey = GeneratedColumn<String>(
    'rule_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _validFromMeta = const VerificationMeta(
    'validFrom',
  );
  @override
  late final GeneratedColumn<String> validFrom = GeneratedColumn<String>(
    'valid_from',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _validToMeta = const VerificationMeta(
    'validTo',
  );
  @override
  late final GeneratedColumn<String> validTo = GeneratedColumn<String>(
    'valid_to',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    updatedAt,
    deletedAt,
    deviceId,
    id,
    ruleKey,
    validFrom,
    validTo,
    json,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rule_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<RuleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('rule_key')) {
      context.handle(
        _ruleKeyMeta,
        ruleKey.isAcceptableOrUnknown(data['rule_key']!, _ruleKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_ruleKeyMeta);
    }
    if (data.containsKey('valid_from')) {
      context.handle(
        _validFromMeta,
        validFrom.isAcceptableOrUnknown(data['valid_from']!, _validFromMeta),
      );
    } else if (isInserting) {
      context.missing(_validFromMeta);
    }
    if (data.containsKey('valid_to')) {
      context.handle(
        _validToMeta,
        validTo.isAcceptableOrUnknown(data['valid_to']!, _validToMeta),
      );
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RuleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RuleRow(
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ruleKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rule_key'],
      )!,
      validFrom: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}valid_from'],
      )!,
      validTo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}valid_to'],
      ),
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
    );
  }

  @override
  $RuleRowsTable createAlias(String alias) {
    return $RuleRowsTable(attachedDatabase, alias);
  }
}

class RuleRow extends DataClass implements Insertable<RuleRow> {
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;
  final String id;
  final String ruleKey;
  final String validFrom;
  final String? validTo;
  final String json;
  const RuleRow({
    required this.updatedAt,
    this.deletedAt,
    required this.deviceId,
    required this.id,
    required this.ruleKey,
    required this.validFrom,
    this.validTo,
    required this.json,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    map['id'] = Variable<String>(id);
    map['rule_key'] = Variable<String>(ruleKey);
    map['valid_from'] = Variable<String>(validFrom);
    if (!nullToAbsent || validTo != null) {
      map['valid_to'] = Variable<String>(validTo);
    }
    map['json'] = Variable<String>(json);
    return map;
  }

  RuleRowsCompanion toCompanion(bool nullToAbsent) {
    return RuleRowsCompanion(
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deviceId: Value(deviceId),
      id: Value(id),
      ruleKey: Value(ruleKey),
      validFrom: Value(validFrom),
      validTo: validTo == null && nullToAbsent
          ? const Value.absent()
          : Value(validTo),
      json: Value(json),
    );
  }

  factory RuleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RuleRow(
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      id: serializer.fromJson<String>(json['id']),
      ruleKey: serializer.fromJson<String>(json['ruleKey']),
      validFrom: serializer.fromJson<String>(json['validFrom']),
      validTo: serializer.fromJson<String?>(json['validTo']),
      json: serializer.fromJson<String>(json['json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'deviceId': serializer.toJson<String>(deviceId),
      'id': serializer.toJson<String>(id),
      'ruleKey': serializer.toJson<String>(ruleKey),
      'validFrom': serializer.toJson<String>(validFrom),
      'validTo': serializer.toJson<String?>(validTo),
      'json': serializer.toJson<String>(json),
    };
  }

  RuleRow copyWith({
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    String? deviceId,
    String? id,
    String? ruleKey,
    String? validFrom,
    Value<String?> validTo = const Value.absent(),
    String? json,
  }) => RuleRow(
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deviceId: deviceId ?? this.deviceId,
    id: id ?? this.id,
    ruleKey: ruleKey ?? this.ruleKey,
    validFrom: validFrom ?? this.validFrom,
    validTo: validTo.present ? validTo.value : this.validTo,
    json: json ?? this.json,
  );
  RuleRow copyWithCompanion(RuleRowsCompanion data) {
    return RuleRow(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      id: data.id.present ? data.id.value : this.id,
      ruleKey: data.ruleKey.present ? data.ruleKey.value : this.ruleKey,
      validFrom: data.validFrom.present ? data.validFrom.value : this.validFrom,
      validTo: data.validTo.present ? data.validTo.value : this.validTo,
      json: data.json.present ? data.json.value : this.json,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RuleRow(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('id: $id, ')
          ..write('ruleKey: $ruleKey, ')
          ..write('validFrom: $validFrom, ')
          ..write('validTo: $validTo, ')
          ..write('json: $json')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    updatedAt,
    deletedAt,
    deviceId,
    id,
    ruleKey,
    validFrom,
    validTo,
    json,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RuleRow &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deviceId == this.deviceId &&
          other.id == this.id &&
          other.ruleKey == this.ruleKey &&
          other.validFrom == this.validFrom &&
          other.validTo == this.validTo &&
          other.json == this.json);
}

class RuleRowsCompanion extends UpdateCompanion<RuleRow> {
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<String> deviceId;
  final Value<String> id;
  final Value<String> ruleKey;
  final Value<String> validFrom;
  final Value<String?> validTo;
  final Value<String> json;
  final Value<int> rowid;
  const RuleRowsCompanion({
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.id = const Value.absent(),
    this.ruleKey = const Value.absent(),
    this.validFrom = const Value.absent(),
    this.validTo = const Value.absent(),
    this.json = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RuleRowsCompanion.insert({
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    required String deviceId,
    required String id,
    required String ruleKey,
    required String validFrom,
    this.validTo = const Value.absent(),
    required String json,
    this.rowid = const Value.absent(),
  }) : updatedAt = Value(updatedAt),
       deviceId = Value(deviceId),
       id = Value(id),
       ruleKey = Value(ruleKey),
       validFrom = Value(validFrom),
       json = Value(json);
  static Insertable<RuleRow> custom({
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<String>? deviceId,
    Expression<String>? id,
    Expression<String>? ruleKey,
    Expression<String>? validFrom,
    Expression<String>? validTo,
    Expression<String>? json,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (id != null) 'id': id,
      if (ruleKey != null) 'rule_key': ruleKey,
      if (validFrom != null) 'valid_from': validFrom,
      if (validTo != null) 'valid_to': validTo,
      if (json != null) 'json': json,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RuleRowsCompanion copyWith({
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<String>? deviceId,
    Value<String>? id,
    Value<String>? ruleKey,
    Value<String>? validFrom,
    Value<String?>? validTo,
    Value<String>? json,
    Value<int>? rowid,
  }) {
    return RuleRowsCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      id: id ?? this.id,
      ruleKey: ruleKey ?? this.ruleKey,
      validFrom: validFrom ?? this.validFrom,
      validTo: validTo ?? this.validTo,
      json: json ?? this.json,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ruleKey.present) {
      map['rule_key'] = Variable<String>(ruleKey.value);
    }
    if (validFrom.present) {
      map['valid_from'] = Variable<String>(validFrom.value);
    }
    if (validTo.present) {
      map['valid_to'] = Variable<String>(validTo.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RuleRowsCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('id: $id, ')
          ..write('ruleKey: $ruleKey, ')
          ..write('validFrom: $validFrom, ')
          ..write('validTo: $validTo, ')
          ..write('json: $json, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OneOffRowsTable extends OneOffRows
    with TableInfo<$OneOffRowsTable, OneOffRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OneOffRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    updatedAt,
    deletedAt,
    deviceId,
    id,
    date,
    json,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'one_off_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<OneOffRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OneOffRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OneOffRow(
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
    );
  }

  @override
  $OneOffRowsTable createAlias(String alias) {
    return $OneOffRowsTable(attachedDatabase, alias);
  }
}

class OneOffRow extends DataClass implements Insertable<OneOffRow> {
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;
  final String id;
  final String date;
  final String json;
  const OneOffRow({
    required this.updatedAt,
    this.deletedAt,
    required this.deviceId,
    required this.id,
    required this.date,
    required this.json,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    map['id'] = Variable<String>(id);
    map['date'] = Variable<String>(date);
    map['json'] = Variable<String>(json);
    return map;
  }

  OneOffRowsCompanion toCompanion(bool nullToAbsent) {
    return OneOffRowsCompanion(
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deviceId: Value(deviceId),
      id: Value(id),
      date: Value(date),
      json: Value(json),
    );
  }

  factory OneOffRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OneOffRow(
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      id: serializer.fromJson<String>(json['id']),
      date: serializer.fromJson<String>(json['date']),
      json: serializer.fromJson<String>(json['json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'deviceId': serializer.toJson<String>(deviceId),
      'id': serializer.toJson<String>(id),
      'date': serializer.toJson<String>(date),
      'json': serializer.toJson<String>(json),
    };
  }

  OneOffRow copyWith({
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    String? deviceId,
    String? id,
    String? date,
    String? json,
  }) => OneOffRow(
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deviceId: deviceId ?? this.deviceId,
    id: id ?? this.id,
    date: date ?? this.date,
    json: json ?? this.json,
  );
  OneOffRow copyWithCompanion(OneOffRowsCompanion data) {
    return OneOffRow(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      json: data.json.present ? data.json.value : this.json,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OneOffRow(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('json: $json')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(updatedAt, deletedAt, deviceId, id, date, json);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OneOffRow &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deviceId == this.deviceId &&
          other.id == this.id &&
          other.date == this.date &&
          other.json == this.json);
}

class OneOffRowsCompanion extends UpdateCompanion<OneOffRow> {
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<String> deviceId;
  final Value<String> id;
  final Value<String> date;
  final Value<String> json;
  final Value<int> rowid;
  const OneOffRowsCompanion({
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.json = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OneOffRowsCompanion.insert({
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    required String deviceId,
    required String id,
    required String date,
    required String json,
    this.rowid = const Value.absent(),
  }) : updatedAt = Value(updatedAt),
       deviceId = Value(deviceId),
       id = Value(id),
       date = Value(date),
       json = Value(json);
  static Insertable<OneOffRow> custom({
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<String>? deviceId,
    Expression<String>? id,
    Expression<String>? date,
    Expression<String>? json,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (json != null) 'json': json,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OneOffRowsCompanion copyWith({
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<String>? deviceId,
    Value<String>? id,
    Value<String>? date,
    Value<String>? json,
    Value<int>? rowid,
  }) {
    return OneOffRowsCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      id: id ?? this.id,
      date: date ?? this.date,
      json: json ?? this.json,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OneOffRowsCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('json: $json, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OverrideRowsTable extends OverrideRows
    with TableInfo<$OverrideRowsTable, OverrideRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OverrideRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemKeyMeta = const VerificationMeta(
    'itemKey',
  );
  @override
  late final GeneratedColumn<String> itemKey = GeneratedColumn<String>(
    'item_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    updatedAt,
    deletedAt,
    deviceId,
    id,
    date,
    itemKey,
    json,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'override_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<OverrideRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('item_key')) {
      context.handle(
        _itemKeyMeta,
        itemKey.isAcceptableOrUnknown(data['item_key']!, _itemKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_itemKeyMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OverrideRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OverrideRow(
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      itemKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_key'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
    );
  }

  @override
  $OverrideRowsTable createAlias(String alias) {
    return $OverrideRowsTable(attachedDatabase, alias);
  }
}

class OverrideRow extends DataClass implements Insertable<OverrideRow> {
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;
  final String id;
  final String date;
  final String itemKey;
  final String json;
  const OverrideRow({
    required this.updatedAt,
    this.deletedAt,
    required this.deviceId,
    required this.id,
    required this.date,
    required this.itemKey,
    required this.json,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    map['id'] = Variable<String>(id);
    map['date'] = Variable<String>(date);
    map['item_key'] = Variable<String>(itemKey);
    map['json'] = Variable<String>(json);
    return map;
  }

  OverrideRowsCompanion toCompanion(bool nullToAbsent) {
    return OverrideRowsCompanion(
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deviceId: Value(deviceId),
      id: Value(id),
      date: Value(date),
      itemKey: Value(itemKey),
      json: Value(json),
    );
  }

  factory OverrideRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OverrideRow(
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      id: serializer.fromJson<String>(json['id']),
      date: serializer.fromJson<String>(json['date']),
      itemKey: serializer.fromJson<String>(json['itemKey']),
      json: serializer.fromJson<String>(json['json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'deviceId': serializer.toJson<String>(deviceId),
      'id': serializer.toJson<String>(id),
      'date': serializer.toJson<String>(date),
      'itemKey': serializer.toJson<String>(itemKey),
      'json': serializer.toJson<String>(json),
    };
  }

  OverrideRow copyWith({
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    String? deviceId,
    String? id,
    String? date,
    String? itemKey,
    String? json,
  }) => OverrideRow(
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deviceId: deviceId ?? this.deviceId,
    id: id ?? this.id,
    date: date ?? this.date,
    itemKey: itemKey ?? this.itemKey,
    json: json ?? this.json,
  );
  OverrideRow copyWithCompanion(OverrideRowsCompanion data) {
    return OverrideRow(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      itemKey: data.itemKey.present ? data.itemKey.value : this.itemKey,
      json: data.json.present ? data.json.value : this.json,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OverrideRow(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('itemKey: $itemKey, ')
          ..write('json: $json')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(updatedAt, deletedAt, deviceId, id, date, itemKey, json);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OverrideRow &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deviceId == this.deviceId &&
          other.id == this.id &&
          other.date == this.date &&
          other.itemKey == this.itemKey &&
          other.json == this.json);
}

class OverrideRowsCompanion extends UpdateCompanion<OverrideRow> {
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<String> deviceId;
  final Value<String> id;
  final Value<String> date;
  final Value<String> itemKey;
  final Value<String> json;
  final Value<int> rowid;
  const OverrideRowsCompanion({
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.itemKey = const Value.absent(),
    this.json = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OverrideRowsCompanion.insert({
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    required String deviceId,
    required String id,
    required String date,
    required String itemKey,
    required String json,
    this.rowid = const Value.absent(),
  }) : updatedAt = Value(updatedAt),
       deviceId = Value(deviceId),
       id = Value(id),
       date = Value(date),
       itemKey = Value(itemKey),
       json = Value(json);
  static Insertable<OverrideRow> custom({
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<String>? deviceId,
    Expression<String>? id,
    Expression<String>? date,
    Expression<String>? itemKey,
    Expression<String>? json,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (itemKey != null) 'item_key': itemKey,
      if (json != null) 'json': json,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OverrideRowsCompanion copyWith({
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<String>? deviceId,
    Value<String>? id,
    Value<String>? date,
    Value<String>? itemKey,
    Value<String>? json,
    Value<int>? rowid,
  }) {
    return OverrideRowsCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      id: id ?? this.id,
      date: date ?? this.date,
      itemKey: itemKey ?? this.itemKey,
      json: json ?? this.json,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (itemKey.present) {
      map['item_key'] = Variable<String>(itemKey.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OverrideRowsCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('itemKey: $itemKey, ')
          ..write('json: $json, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CarryRowsTable extends CarryRows
    with TableInfo<$CarryRowsTable, CarryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CarryRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toDateMeta = const VerificationMeta('toDate');
  @override
  late final GeneratedColumn<String> toDate = GeneratedColumn<String>(
    'to_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    updatedAt,
    deletedAt,
    deviceId,
    id,
    toDate,
    json,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'carry_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<CarryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('to_date')) {
      context.handle(
        _toDateMeta,
        toDate.isAcceptableOrUnknown(data['to_date']!, _toDateMeta),
      );
    } else if (isInserting) {
      context.missing(_toDateMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CarryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CarryRow(
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      toDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_date'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
    );
  }

  @override
  $CarryRowsTable createAlias(String alias) {
    return $CarryRowsTable(attachedDatabase, alias);
  }
}

class CarryRow extends DataClass implements Insertable<CarryRow> {
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;
  final String id;
  final String toDate;
  final String json;
  const CarryRow({
    required this.updatedAt,
    this.deletedAt,
    required this.deviceId,
    required this.id,
    required this.toDate,
    required this.json,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    map['id'] = Variable<String>(id);
    map['to_date'] = Variable<String>(toDate);
    map['json'] = Variable<String>(json);
    return map;
  }

  CarryRowsCompanion toCompanion(bool nullToAbsent) {
    return CarryRowsCompanion(
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deviceId: Value(deviceId),
      id: Value(id),
      toDate: Value(toDate),
      json: Value(json),
    );
  }

  factory CarryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CarryRow(
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      id: serializer.fromJson<String>(json['id']),
      toDate: serializer.fromJson<String>(json['toDate']),
      json: serializer.fromJson<String>(json['json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'deviceId': serializer.toJson<String>(deviceId),
      'id': serializer.toJson<String>(id),
      'toDate': serializer.toJson<String>(toDate),
      'json': serializer.toJson<String>(json),
    };
  }

  CarryRow copyWith({
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    String? deviceId,
    String? id,
    String? toDate,
    String? json,
  }) => CarryRow(
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deviceId: deviceId ?? this.deviceId,
    id: id ?? this.id,
    toDate: toDate ?? this.toDate,
    json: json ?? this.json,
  );
  CarryRow copyWithCompanion(CarryRowsCompanion data) {
    return CarryRow(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      id: data.id.present ? data.id.value : this.id,
      toDate: data.toDate.present ? data.toDate.value : this.toDate,
      json: data.json.present ? data.json.value : this.json,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CarryRow(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('id: $id, ')
          ..write('toDate: $toDate, ')
          ..write('json: $json')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(updatedAt, deletedAt, deviceId, id, toDate, json);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CarryRow &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deviceId == this.deviceId &&
          other.id == this.id &&
          other.toDate == this.toDate &&
          other.json == this.json);
}

class CarryRowsCompanion extends UpdateCompanion<CarryRow> {
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<String> deviceId;
  final Value<String> id;
  final Value<String> toDate;
  final Value<String> json;
  final Value<int> rowid;
  const CarryRowsCompanion({
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.id = const Value.absent(),
    this.toDate = const Value.absent(),
    this.json = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CarryRowsCompanion.insert({
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    required String deviceId,
    required String id,
    required String toDate,
    required String json,
    this.rowid = const Value.absent(),
  }) : updatedAt = Value(updatedAt),
       deviceId = Value(deviceId),
       id = Value(id),
       toDate = Value(toDate),
       json = Value(json);
  static Insertable<CarryRow> custom({
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<String>? deviceId,
    Expression<String>? id,
    Expression<String>? toDate,
    Expression<String>? json,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (id != null) 'id': id,
      if (toDate != null) 'to_date': toDate,
      if (json != null) 'json': json,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CarryRowsCompanion copyWith({
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<String>? deviceId,
    Value<String>? id,
    Value<String>? toDate,
    Value<String>? json,
    Value<int>? rowid,
  }) {
    return CarryRowsCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      id: id ?? this.id,
      toDate: toDate ?? this.toDate,
      json: json ?? this.json,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (toDate.present) {
      map['to_date'] = Variable<String>(toDate.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CarryRowsCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('id: $id, ')
          ..write('toDate: $toDate, ')
          ..write('json: $json, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LogRowsTable extends LogRows with TableInfo<$LogRowsTable, LogRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LogRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemKeyMeta = const VerificationMeta(
    'itemKey',
  );
  @override
  late final GeneratedColumn<String> itemKey = GeneratedColumn<String>(
    'item_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    updatedAt,
    deletedAt,
    deviceId,
    id,
    date,
    itemKey,
    status,
    category,
    json,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'log_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<LogRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('item_key')) {
      context.handle(
        _itemKeyMeta,
        itemKey.isAcceptableOrUnknown(data['item_key']!, _itemKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_itemKeyMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LogRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LogRow(
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      itemKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_key'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
    );
  }

  @override
  $LogRowsTable createAlias(String alias) {
    return $LogRowsTable(attachedDatabase, alias);
  }
}

class LogRow extends DataClass implements Insertable<LogRow> {
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;
  final String id;
  final String date;
  final String itemKey;
  final String status;
  final String? category;
  final String json;
  const LogRow({
    required this.updatedAt,
    this.deletedAt,
    required this.deviceId,
    required this.id,
    required this.date,
    required this.itemKey,
    required this.status,
    this.category,
    required this.json,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    map['id'] = Variable<String>(id);
    map['date'] = Variable<String>(date);
    map['item_key'] = Variable<String>(itemKey);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    map['json'] = Variable<String>(json);
    return map;
  }

  LogRowsCompanion toCompanion(bool nullToAbsent) {
    return LogRowsCompanion(
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deviceId: Value(deviceId),
      id: Value(id),
      date: Value(date),
      itemKey: Value(itemKey),
      status: Value(status),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      json: Value(json),
    );
  }

  factory LogRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LogRow(
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      id: serializer.fromJson<String>(json['id']),
      date: serializer.fromJson<String>(json['date']),
      itemKey: serializer.fromJson<String>(json['itemKey']),
      status: serializer.fromJson<String>(json['status']),
      category: serializer.fromJson<String?>(json['category']),
      json: serializer.fromJson<String>(json['json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'deviceId': serializer.toJson<String>(deviceId),
      'id': serializer.toJson<String>(id),
      'date': serializer.toJson<String>(date),
      'itemKey': serializer.toJson<String>(itemKey),
      'status': serializer.toJson<String>(status),
      'category': serializer.toJson<String?>(category),
      'json': serializer.toJson<String>(json),
    };
  }

  LogRow copyWith({
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    String? deviceId,
    String? id,
    String? date,
    String? itemKey,
    String? status,
    Value<String?> category = const Value.absent(),
    String? json,
  }) => LogRow(
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deviceId: deviceId ?? this.deviceId,
    id: id ?? this.id,
    date: date ?? this.date,
    itemKey: itemKey ?? this.itemKey,
    status: status ?? this.status,
    category: category.present ? category.value : this.category,
    json: json ?? this.json,
  );
  LogRow copyWithCompanion(LogRowsCompanion data) {
    return LogRow(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      itemKey: data.itemKey.present ? data.itemKey.value : this.itemKey,
      status: data.status.present ? data.status.value : this.status,
      category: data.category.present ? data.category.value : this.category,
      json: data.json.present ? data.json.value : this.json,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LogRow(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('itemKey: $itemKey, ')
          ..write('status: $status, ')
          ..write('category: $category, ')
          ..write('json: $json')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    updatedAt,
    deletedAt,
    deviceId,
    id,
    date,
    itemKey,
    status,
    category,
    json,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LogRow &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deviceId == this.deviceId &&
          other.id == this.id &&
          other.date == this.date &&
          other.itemKey == this.itemKey &&
          other.status == this.status &&
          other.category == this.category &&
          other.json == this.json);
}

class LogRowsCompanion extends UpdateCompanion<LogRow> {
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<String> deviceId;
  final Value<String> id;
  final Value<String> date;
  final Value<String> itemKey;
  final Value<String> status;
  final Value<String?> category;
  final Value<String> json;
  final Value<int> rowid;
  const LogRowsCompanion({
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.itemKey = const Value.absent(),
    this.status = const Value.absent(),
    this.category = const Value.absent(),
    this.json = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LogRowsCompanion.insert({
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    required String deviceId,
    required String id,
    required String date,
    required String itemKey,
    required String status,
    this.category = const Value.absent(),
    required String json,
    this.rowid = const Value.absent(),
  }) : updatedAt = Value(updatedAt),
       deviceId = Value(deviceId),
       id = Value(id),
       date = Value(date),
       itemKey = Value(itemKey),
       status = Value(status),
       json = Value(json);
  static Insertable<LogRow> custom({
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<String>? deviceId,
    Expression<String>? id,
    Expression<String>? date,
    Expression<String>? itemKey,
    Expression<String>? status,
    Expression<String>? category,
    Expression<String>? json,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (itemKey != null) 'item_key': itemKey,
      if (status != null) 'status': status,
      if (category != null) 'category': category,
      if (json != null) 'json': json,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LogRowsCompanion copyWith({
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<String>? deviceId,
    Value<String>? id,
    Value<String>? date,
    Value<String>? itemKey,
    Value<String>? status,
    Value<String?>? category,
    Value<String>? json,
    Value<int>? rowid,
  }) {
    return LogRowsCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      id: id ?? this.id,
      date: date ?? this.date,
      itemKey: itemKey ?? this.itemKey,
      status: status ?? this.status,
      category: category ?? this.category,
      json: json ?? this.json,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (itemKey.present) {
      map['item_key'] = Variable<String>(itemKey.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LogRowsCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('itemKey: $itemKey, ')
          ..write('status: $status, ')
          ..write('category: $category, ')
          ..write('json: $json, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $KvEntriesTable kvEntries = $KvEntriesTable(this);
  late final $RuleRowsTable ruleRows = $RuleRowsTable(this);
  late final $OneOffRowsTable oneOffRows = $OneOffRowsTable(this);
  late final $OverrideRowsTable overrideRows = $OverrideRowsTable(this);
  late final $CarryRowsTable carryRows = $CarryRowsTable(this);
  late final $LogRowsTable logRows = $LogRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    kvEntries,
    ruleRows,
    oneOffRows,
    overrideRows,
    carryRows,
    logRows,
  ];
}

typedef $$KvEntriesTableCreateCompanionBuilder =
    KvEntriesCompanion Function({
      required String key,
      required String value,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$KvEntriesTableUpdateCompanionBuilder =
    KvEntriesCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$KvEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $KvEntriesTable> {
  $$KvEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$KvEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $KvEntriesTable> {
  $$KvEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$KvEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $KvEntriesTable> {
  $$KvEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$KvEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $KvEntriesTable,
          KvEntry,
          $$KvEntriesTableFilterComposer,
          $$KvEntriesTableOrderingComposer,
          $$KvEntriesTableAnnotationComposer,
          $$KvEntriesTableCreateCompanionBuilder,
          $$KvEntriesTableUpdateCompanionBuilder,
          (KvEntry, BaseReferences<_$AppDatabase, $KvEntriesTable, KvEntry>),
          KvEntry,
          PrefetchHooks Function()
        > {
  $$KvEntriesTableTableManager(_$AppDatabase db, $KvEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KvEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KvEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KvEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KvEntriesCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => KvEntriesCompanion.insert(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$KvEntriesTable, KvEntry>(table),
                  BaseReferences<_$AppDatabase, $KvEntriesTable, KvEntry>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$KvEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $KvEntriesTable,
      KvEntry,
      $$KvEntriesTableFilterComposer,
      $$KvEntriesTableOrderingComposer,
      $$KvEntriesTableAnnotationComposer,
      $$KvEntriesTableCreateCompanionBuilder,
      $$KvEntriesTableUpdateCompanionBuilder,
      (KvEntry, BaseReferences<_$AppDatabase, $KvEntriesTable, KvEntry>),
      KvEntry,
      PrefetchHooks Function()
    >;
typedef $$RuleRowsTableCreateCompanionBuilder =
    RuleRowsCompanion Function({
      required int updatedAt,
      Value<int?> deletedAt,
      required String deviceId,
      required String id,
      required String ruleKey,
      required String validFrom,
      Value<String?> validTo,
      required String json,
      Value<int> rowid,
    });
typedef $$RuleRowsTableUpdateCompanionBuilder =
    RuleRowsCompanion Function({
      Value<int> updatedAt,
      Value<int?> deletedAt,
      Value<String> deviceId,
      Value<String> id,
      Value<String> ruleKey,
      Value<String> validFrom,
      Value<String?> validTo,
      Value<String> json,
      Value<int> rowid,
    });

class $$RuleRowsTableFilterComposer
    extends Composer<_$AppDatabase, $RuleRowsTable> {
  $$RuleRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ruleKey => $composableBuilder(
    column: $table.ruleKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get validFrom => $composableBuilder(
    column: $table.validFrom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get validTo => $composableBuilder(
    column: $table.validTo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RuleRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $RuleRowsTable> {
  $$RuleRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ruleKey => $composableBuilder(
    column: $table.ruleKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get validFrom => $composableBuilder(
    column: $table.validFrom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get validTo => $composableBuilder(
    column: $table.validTo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RuleRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RuleRowsTable> {
  $$RuleRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ruleKey =>
      $composableBuilder(column: $table.ruleKey, builder: (column) => column);

  GeneratedColumn<String> get validFrom =>
      $composableBuilder(column: $table.validFrom, builder: (column) => column);

  GeneratedColumn<String> get validTo =>
      $composableBuilder(column: $table.validTo, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);
}

class $$RuleRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RuleRowsTable,
          RuleRow,
          $$RuleRowsTableFilterComposer,
          $$RuleRowsTableOrderingComposer,
          $$RuleRowsTableAnnotationComposer,
          $$RuleRowsTableCreateCompanionBuilder,
          $$RuleRowsTableUpdateCompanionBuilder,
          (RuleRow, BaseReferences<_$AppDatabase, $RuleRowsTable, RuleRow>),
          RuleRow,
          PrefetchHooks Function()
        > {
  $$RuleRowsTableTableManager(_$AppDatabase db, $RuleRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RuleRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RuleRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RuleRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> ruleKey = const Value.absent(),
                Value<String> validFrom = const Value.absent(),
                Value<String?> validTo = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RuleRowsCompanion(
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                id: id,
                ruleKey: ruleKey,
                validFrom: validFrom,
                validTo: validTo,
                json: json,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                required String deviceId,
                required String id,
                required String ruleKey,
                required String validFrom,
                Value<String?> validTo = const Value.absent(),
                required String json,
                Value<int> rowid = const Value.absent(),
              }) => RuleRowsCompanion.insert(
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                id: id,
                ruleKey: ruleKey,
                validFrom: validFrom,
                validTo: validTo,
                json: json,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RuleRowsTable, RuleRow>(table),
                  BaseReferences<_$AppDatabase, $RuleRowsTable, RuleRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RuleRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RuleRowsTable,
      RuleRow,
      $$RuleRowsTableFilterComposer,
      $$RuleRowsTableOrderingComposer,
      $$RuleRowsTableAnnotationComposer,
      $$RuleRowsTableCreateCompanionBuilder,
      $$RuleRowsTableUpdateCompanionBuilder,
      (RuleRow, BaseReferences<_$AppDatabase, $RuleRowsTable, RuleRow>),
      RuleRow,
      PrefetchHooks Function()
    >;
typedef $$OneOffRowsTableCreateCompanionBuilder =
    OneOffRowsCompanion Function({
      required int updatedAt,
      Value<int?> deletedAt,
      required String deviceId,
      required String id,
      required String date,
      required String json,
      Value<int> rowid,
    });
typedef $$OneOffRowsTableUpdateCompanionBuilder =
    OneOffRowsCompanion Function({
      Value<int> updatedAt,
      Value<int?> deletedAt,
      Value<String> deviceId,
      Value<String> id,
      Value<String> date,
      Value<String> json,
      Value<int> rowid,
    });

class $$OneOffRowsTableFilterComposer
    extends Composer<_$AppDatabase, $OneOffRowsTable> {
  $$OneOffRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OneOffRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $OneOffRowsTable> {
  $$OneOffRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OneOffRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OneOffRowsTable> {
  $$OneOffRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);
}

class $$OneOffRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OneOffRowsTable,
          OneOffRow,
          $$OneOffRowsTableFilterComposer,
          $$OneOffRowsTableOrderingComposer,
          $$OneOffRowsTableAnnotationComposer,
          $$OneOffRowsTableCreateCompanionBuilder,
          $$OneOffRowsTableUpdateCompanionBuilder,
          (
            OneOffRow,
            BaseReferences<_$AppDatabase, $OneOffRowsTable, OneOffRow>,
          ),
          OneOffRow,
          PrefetchHooks Function()
        > {
  $$OneOffRowsTableTableManager(_$AppDatabase db, $OneOffRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OneOffRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OneOffRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OneOffRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OneOffRowsCompanion(
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                id: id,
                date: date,
                json: json,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                required String deviceId,
                required String id,
                required String date,
                required String json,
                Value<int> rowid = const Value.absent(),
              }) => OneOffRowsCompanion.insert(
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                id: id,
                date: date,
                json: json,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OneOffRowsTable, OneOffRow>(table),
                  BaseReferences<_$AppDatabase, $OneOffRowsTable, OneOffRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OneOffRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OneOffRowsTable,
      OneOffRow,
      $$OneOffRowsTableFilterComposer,
      $$OneOffRowsTableOrderingComposer,
      $$OneOffRowsTableAnnotationComposer,
      $$OneOffRowsTableCreateCompanionBuilder,
      $$OneOffRowsTableUpdateCompanionBuilder,
      (OneOffRow, BaseReferences<_$AppDatabase, $OneOffRowsTable, OneOffRow>),
      OneOffRow,
      PrefetchHooks Function()
    >;
typedef $$OverrideRowsTableCreateCompanionBuilder =
    OverrideRowsCompanion Function({
      required int updatedAt,
      Value<int?> deletedAt,
      required String deviceId,
      required String id,
      required String date,
      required String itemKey,
      required String json,
      Value<int> rowid,
    });
typedef $$OverrideRowsTableUpdateCompanionBuilder =
    OverrideRowsCompanion Function({
      Value<int> updatedAt,
      Value<int?> deletedAt,
      Value<String> deviceId,
      Value<String> id,
      Value<String> date,
      Value<String> itemKey,
      Value<String> json,
      Value<int> rowid,
    });

class $$OverrideRowsTableFilterComposer
    extends Composer<_$AppDatabase, $OverrideRowsTable> {
  $$OverrideRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemKey => $composableBuilder(
    column: $table.itemKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OverrideRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $OverrideRowsTable> {
  $$OverrideRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemKey => $composableBuilder(
    column: $table.itemKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OverrideRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OverrideRowsTable> {
  $$OverrideRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get itemKey =>
      $composableBuilder(column: $table.itemKey, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);
}

class $$OverrideRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OverrideRowsTable,
          OverrideRow,
          $$OverrideRowsTableFilterComposer,
          $$OverrideRowsTableOrderingComposer,
          $$OverrideRowsTableAnnotationComposer,
          $$OverrideRowsTableCreateCompanionBuilder,
          $$OverrideRowsTableUpdateCompanionBuilder,
          (
            OverrideRow,
            BaseReferences<_$AppDatabase, $OverrideRowsTable, OverrideRow>,
          ),
          OverrideRow,
          PrefetchHooks Function()
        > {
  $$OverrideRowsTableTableManager(_$AppDatabase db, $OverrideRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OverrideRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OverrideRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OverrideRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<String> itemKey = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OverrideRowsCompanion(
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                id: id,
                date: date,
                itemKey: itemKey,
                json: json,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                required String deviceId,
                required String id,
                required String date,
                required String itemKey,
                required String json,
                Value<int> rowid = const Value.absent(),
              }) => OverrideRowsCompanion.insert(
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                id: id,
                date: date,
                itemKey: itemKey,
                json: json,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OverrideRowsTable, OverrideRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $OverrideRowsTable,
                    OverrideRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OverrideRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OverrideRowsTable,
      OverrideRow,
      $$OverrideRowsTableFilterComposer,
      $$OverrideRowsTableOrderingComposer,
      $$OverrideRowsTableAnnotationComposer,
      $$OverrideRowsTableCreateCompanionBuilder,
      $$OverrideRowsTableUpdateCompanionBuilder,
      (
        OverrideRow,
        BaseReferences<_$AppDatabase, $OverrideRowsTable, OverrideRow>,
      ),
      OverrideRow,
      PrefetchHooks Function()
    >;
typedef $$CarryRowsTableCreateCompanionBuilder =
    CarryRowsCompanion Function({
      required int updatedAt,
      Value<int?> deletedAt,
      required String deviceId,
      required String id,
      required String toDate,
      required String json,
      Value<int> rowid,
    });
typedef $$CarryRowsTableUpdateCompanionBuilder =
    CarryRowsCompanion Function({
      Value<int> updatedAt,
      Value<int?> deletedAt,
      Value<String> deviceId,
      Value<String> id,
      Value<String> toDate,
      Value<String> json,
      Value<int> rowid,
    });

class $$CarryRowsTableFilterComposer
    extends Composer<_$AppDatabase, $CarryRowsTable> {
  $$CarryRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toDate => $composableBuilder(
    column: $table.toDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CarryRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $CarryRowsTable> {
  $$CarryRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toDate => $composableBuilder(
    column: $table.toDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CarryRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CarryRowsTable> {
  $$CarryRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get toDate =>
      $composableBuilder(column: $table.toDate, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);
}

class $$CarryRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CarryRowsTable,
          CarryRow,
          $$CarryRowsTableFilterComposer,
          $$CarryRowsTableOrderingComposer,
          $$CarryRowsTableAnnotationComposer,
          $$CarryRowsTableCreateCompanionBuilder,
          $$CarryRowsTableUpdateCompanionBuilder,
          (CarryRow, BaseReferences<_$AppDatabase, $CarryRowsTable, CarryRow>),
          CarryRow,
          PrefetchHooks Function()
        > {
  $$CarryRowsTableTableManager(_$AppDatabase db, $CarryRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CarryRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CarryRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CarryRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> toDate = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CarryRowsCompanion(
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                id: id,
                toDate: toDate,
                json: json,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                required String deviceId,
                required String id,
                required String toDate,
                required String json,
                Value<int> rowid = const Value.absent(),
              }) => CarryRowsCompanion.insert(
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                id: id,
                toDate: toDate,
                json: json,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CarryRowsTable, CarryRow>(table),
                  BaseReferences<_$AppDatabase, $CarryRowsTable, CarryRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CarryRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CarryRowsTable,
      CarryRow,
      $$CarryRowsTableFilterComposer,
      $$CarryRowsTableOrderingComposer,
      $$CarryRowsTableAnnotationComposer,
      $$CarryRowsTableCreateCompanionBuilder,
      $$CarryRowsTableUpdateCompanionBuilder,
      (CarryRow, BaseReferences<_$AppDatabase, $CarryRowsTable, CarryRow>),
      CarryRow,
      PrefetchHooks Function()
    >;
typedef $$LogRowsTableCreateCompanionBuilder =
    LogRowsCompanion Function({
      required int updatedAt,
      Value<int?> deletedAt,
      required String deviceId,
      required String id,
      required String date,
      required String itemKey,
      required String status,
      Value<String?> category,
      required String json,
      Value<int> rowid,
    });
typedef $$LogRowsTableUpdateCompanionBuilder =
    LogRowsCompanion Function({
      Value<int> updatedAt,
      Value<int?> deletedAt,
      Value<String> deviceId,
      Value<String> id,
      Value<String> date,
      Value<String> itemKey,
      Value<String> status,
      Value<String?> category,
      Value<String> json,
      Value<int> rowid,
    });

class $$LogRowsTableFilterComposer
    extends Composer<_$AppDatabase, $LogRowsTable> {
  $$LogRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemKey => $composableBuilder(
    column: $table.itemKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LogRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $LogRowsTable> {
  $$LogRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemKey => $composableBuilder(
    column: $table.itemKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LogRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LogRowsTable> {
  $$LogRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get itemKey =>
      $composableBuilder(column: $table.itemKey, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);
}

class $$LogRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LogRowsTable,
          LogRow,
          $$LogRowsTableFilterComposer,
          $$LogRowsTableOrderingComposer,
          $$LogRowsTableAnnotationComposer,
          $$LogRowsTableCreateCompanionBuilder,
          $$LogRowsTableUpdateCompanionBuilder,
          (LogRow, BaseReferences<_$AppDatabase, $LogRowsTable, LogRow>),
          LogRow,
          PrefetchHooks Function()
        > {
  $$LogRowsTableTableManager(_$AppDatabase db, $LogRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LogRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LogRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LogRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<String> itemKey = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LogRowsCompanion(
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                id: id,
                date: date,
                itemKey: itemKey,
                status: status,
                category: category,
                json: json,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                required String deviceId,
                required String id,
                required String date,
                required String itemKey,
                required String status,
                Value<String?> category = const Value.absent(),
                required String json,
                Value<int> rowid = const Value.absent(),
              }) => LogRowsCompanion.insert(
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                id: id,
                date: date,
                itemKey: itemKey,
                status: status,
                category: category,
                json: json,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LogRowsTable, LogRow>(table),
                  BaseReferences<_$AppDatabase, $LogRowsTable, LogRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LogRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LogRowsTable,
      LogRow,
      $$LogRowsTableFilterComposer,
      $$LogRowsTableOrderingComposer,
      $$LogRowsTableAnnotationComposer,
      $$LogRowsTableCreateCompanionBuilder,
      $$LogRowsTableUpdateCompanionBuilder,
      (LogRow, BaseReferences<_$AppDatabase, $LogRowsTable, LogRow>),
      LogRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$KvEntriesTableTableManager get kvEntries =>
      $$KvEntriesTableTableManager(_db, _db.kvEntries);
  $$RuleRowsTableTableManager get ruleRows =>
      $$RuleRowsTableTableManager(_db, _db.ruleRows);
  $$OneOffRowsTableTableManager get oneOffRows =>
      $$OneOffRowsTableTableManager(_db, _db.oneOffRows);
  $$OverrideRowsTableTableManager get overrideRows =>
      $$OverrideRowsTableTableManager(_db, _db.overrideRows);
  $$CarryRowsTableTableManager get carryRows =>
      $$CarryRowsTableTableManager(_db, _db.carryRows);
  $$LogRowsTableTableManager get logRows =>
      $$LogRowsTableTableManager(_db, _db.logRows);
}
