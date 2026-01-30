/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;

abstract class Alert implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  Alert._({
    this.id,
    required this.userId,
    required this.deviceId,
    required this.time,
    required this.alertType,
    required this.isResolved,
  });

  factory Alert({
    int? id,
    required int userId,
    required int deviceId,
    required DateTime time,
    required String alertType,
    required bool isResolved,
  }) = _AlertImpl;

  factory Alert.fromJson(Map<String, dynamic> jsonSerialization) {
    return Alert(
      id: jsonSerialization['id'] as int?,
      userId: jsonSerialization['userId'] as int,
      deviceId: jsonSerialization['deviceId'] as int,
      time: _i1.DateTimeJsonExtension.fromJson(jsonSerialization['time']),
      alertType: jsonSerialization['alertType'] as String,
      isResolved: jsonSerialization['isResolved'] as bool,
    );
  }

  static final t = AlertTable();

  static const db = AlertRepository._();

  @override
  int? id;

  int userId;

  int deviceId;

  DateTime time;

  String alertType;

  bool isResolved;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [Alert]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  Alert copyWith({
    int? id,
    int? userId,
    int? deviceId,
    DateTime? time,
    String? alertType,
    bool? isResolved,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Alert',
      if (id != null) 'id': id,
      'userId': userId,
      'deviceId': deviceId,
      'time': time.toJson(),
      'alertType': alertType,
      'isResolved': isResolved,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Alert',
      if (id != null) 'id': id,
      'userId': userId,
      'deviceId': deviceId,
      'time': time.toJson(),
      'alertType': alertType,
      'isResolved': isResolved,
    };
  }

  static AlertInclude include() {
    return AlertInclude._();
  }

  static AlertIncludeList includeList({
    _i1.WhereExpressionBuilder<AlertTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<AlertTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<AlertTable>? orderByList,
    AlertInclude? include,
  }) {
    return AlertIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Alert.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(Alert.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AlertImpl extends Alert {
  _AlertImpl({
    int? id,
    required int userId,
    required int deviceId,
    required DateTime time,
    required String alertType,
    required bool isResolved,
  }) : super._(
         id: id,
         userId: userId,
         deviceId: deviceId,
         time: time,
         alertType: alertType,
         isResolved: isResolved,
       );

  /// Returns a shallow copy of this [Alert]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  Alert copyWith({
    Object? id = _Undefined,
    int? userId,
    int? deviceId,
    DateTime? time,
    String? alertType,
    bool? isResolved,
  }) {
    return Alert(
      id: id is int? ? id : this.id,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      time: time ?? this.time,
      alertType: alertType ?? this.alertType,
      isResolved: isResolved ?? this.isResolved,
    );
  }
}

class AlertUpdateTable extends _i1.UpdateTable<AlertTable> {
  AlertUpdateTable(super.table);

  _i1.ColumnValue<int, int> userId(int value) => _i1.ColumnValue(
    table.userId,
    value,
  );

  _i1.ColumnValue<int, int> deviceId(int value) => _i1.ColumnValue(
    table.deviceId,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> time(DateTime value) => _i1.ColumnValue(
    table.time,
    value,
  );

  _i1.ColumnValue<String, String> alertType(String value) => _i1.ColumnValue(
    table.alertType,
    value,
  );

  _i1.ColumnValue<bool, bool> isResolved(bool value) => _i1.ColumnValue(
    table.isResolved,
    value,
  );
}

class AlertTable extends _i1.Table<int?> {
  AlertTable({super.tableRelation}) : super(tableName: 'alert') {
    updateTable = AlertUpdateTable(this);
    userId = _i1.ColumnInt(
      'userId',
      this,
    );
    deviceId = _i1.ColumnInt(
      'deviceId',
      this,
    );
    time = _i1.ColumnDateTime(
      'time',
      this,
    );
    alertType = _i1.ColumnString(
      'alertType',
      this,
    );
    isResolved = _i1.ColumnBool(
      'isResolved',
      this,
    );
  }

  late final AlertUpdateTable updateTable;

  late final _i1.ColumnInt userId;

  late final _i1.ColumnInt deviceId;

  late final _i1.ColumnDateTime time;

  late final _i1.ColumnString alertType;

  late final _i1.ColumnBool isResolved;

  @override
  List<_i1.Column> get columns => [
    id,
    userId,
    deviceId,
    time,
    alertType,
    isResolved,
  ];
}

class AlertInclude extends _i1.IncludeObject {
  AlertInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => Alert.t;
}

class AlertIncludeList extends _i1.IncludeList {
  AlertIncludeList._({
    _i1.WhereExpressionBuilder<AlertTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(Alert.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => Alert.t;
}

class AlertRepository {
  const AlertRepository._();

  /// Returns a list of [Alert]s matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order of the items use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// The maximum number of items can be set by [limit]. If no limit is set,
  /// all items matching the query will be returned.
  ///
  /// [offset] defines how many items to skip, after which [limit] (or all)
  /// items are read from the database.
  ///
  /// ```dart
  /// var persons = await Persons.db.find(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.firstName,
  ///   limit: 100,
  /// );
  /// ```
  Future<List<Alert>> find(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<AlertTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<AlertTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<AlertTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<Alert>(
      where: where?.call(Alert.t),
      orderBy: orderBy?.call(Alert.t),
      orderByList: orderByList?.call(Alert.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Returns the first matching [Alert] matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// [offset] defines how many items to skip, after which the next one will be picked.
  ///
  /// ```dart
  /// var youngestPerson = await Persons.db.findFirstRow(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.age,
  /// );
  /// ```
  Future<Alert?> findFirstRow(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<AlertTable>? where,
    int? offset,
    _i1.OrderByBuilder<AlertTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<AlertTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findFirstRow<Alert>(
      where: where?.call(Alert.t),
      orderBy: orderBy?.call(Alert.t),
      orderByList: orderByList?.call(Alert.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Finds a single [Alert] by its [id] or null if no such row exists.
  Future<Alert?> findById(
    _i1.Session session,
    int id, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.findById<Alert>(
      id,
      transaction: transaction,
    );
  }

  /// Inserts all [Alert]s in the list and returns the inserted rows.
  ///
  /// The returned [Alert]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  Future<List<Alert>> insert(
    _i1.Session session,
    List<Alert> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert<Alert>(
      rows,
      transaction: transaction,
    );
  }

  /// Inserts a single [Alert] and returns the inserted row.
  ///
  /// The returned [Alert] will have its `id` field set.
  Future<Alert> insertRow(
    _i1.Session session,
    Alert row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<Alert>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [Alert]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<Alert>> update(
    _i1.Session session,
    List<Alert> rows, {
    _i1.ColumnSelections<AlertTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<Alert>(
      rows,
      columns: columns?.call(Alert.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Alert]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<Alert> updateRow(
    _i1.Session session,
    Alert row, {
    _i1.ColumnSelections<AlertTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<Alert>(
      row,
      columns: columns?.call(Alert.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Alert] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<Alert?> updateById(
    _i1.Session session,
    int id, {
    required _i1.ColumnValueListBuilder<AlertUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<Alert>(
      id,
      columnValues: columnValues(Alert.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [Alert]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<Alert>> updateWhere(
    _i1.Session session, {
    required _i1.ColumnValueListBuilder<AlertUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<AlertTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<AlertTable>? orderBy,
    _i1.OrderByListBuilder<AlertTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<Alert>(
      columnValues: columnValues(Alert.t.updateTable),
      where: where(Alert.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Alert.t),
      orderByList: orderByList?.call(Alert.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [Alert]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<Alert>> delete(
    _i1.Session session,
    List<Alert> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<Alert>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [Alert].
  Future<Alert> deleteRow(
    _i1.Session session,
    Alert row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<Alert>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<Alert>> deleteWhere(
    _i1.Session session, {
    required _i1.WhereExpressionBuilder<AlertTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<Alert>(
      where: where(Alert.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<AlertTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<Alert>(
      where: where?.call(Alert.t),
      limit: limit,
      transaction: transaction,
    );
  }
}
