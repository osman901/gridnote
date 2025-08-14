
import 'package:flutter/material.dart';

class DataTableWidget extends StatelessWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;

  const DataTableWidget({super.key, required this.columns, required this.rows});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(Colors.grey[900]),
        columns: columns,
        rows: rows,
        dataRowColor: MaterialStateProperty.all(Colors.black),
        columnSpacing: 20,
        dividerThickness: 1,
      ),
    );
  }
}
