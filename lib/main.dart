import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:async';

void main() {
  runApp(AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Class Attendance System',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: LecturerDashboard(),
    );
  }
}

class LecturerDashboard extends StatefulWidget {
  @override
  _LecturerDashboardState createState() => _LecturerDashboardState();
}

class _LecturerDashboardState extends State<LecturerDashboard> {
  Database? _database;
  final TextEditingController _maxDaysController = TextEditingController();
  List<Map<String, dynamic>> _students = [];

  @override
  void initState() {
    super.initState();
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    String path = p.join(await getDatabasesPath(), 'attendance.db');
    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        db.execute(
            'CREATE TABLE IF NOT EXISTS students(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, regNumber TEXT, attended INTEGER DEFAULT 0)');
      },
    );
    _refreshStudentList();
  }

  Future<void> _refreshStudentList() async {
    final students = await _database?.query('students') ?? [];
    setState(() {
      _students = students;
    });
  }

  Future<void> _markAttendance(int id, int attended) async {
    await _database?.update(
      'students',
      {'attended': attended + 1},
      where: 'id = ?',
      whereArgs: [id],
    );
    _refreshStudentList();
  }

  void _saveMaxDays() {
    setState(() {
      _refreshStudentList();
    });
  }

  double _calculateMarks(int attended, int maxDays) {
    if (maxDays <= 0) return 0;
    return (attended / maxDays) * 10;
  }

  Future<void> _generateAndShareExcel() async {
    final excel = Excel.createExcel();
    final sheet = excel['Attendance'];

    sheet.appendRow([
      TextCellValue('Name'),
      TextCellValue('Reg Number'),
      TextCellValue('Attended Days'),
      TextCellValue('Marks')
    ]);
    int maxDays = int.tryParse(_maxDaysController.text) ?? 1;

    for (var student in _students) {
      int attended = (student['attended'] as int?) ?? 0;
      double marks = _calculateMarks(attended, maxDays);
      sheet.appendRow([
        TextCellValue(student['name']),
        TextCellValue(student['regNumber']),
        IntCellValue(attended),
        TextCellValue(marks.toStringAsFixed(2))
      ]);
    }

    final directory = await getApplicationDocumentsDirectory();
    final filePath = p.join(directory.path, 'AttendanceReport.xlsx');
    final file = File(filePath);
    await file.writeAsBytes(excel.encode()!);

    await Share.shareXFiles([XFile(filePath)], text: 'Class Attendance Report');
  }

  void _navigateToStudentRegistration() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentRegistrationPage(
            database: _database, refreshList: _refreshStudentList),
      ),
    ).then((_) => _refreshStudentList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Class Attendance System')),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'share',
            onPressed: _generateAndShareExcel,
            child: Icon(Icons.share),
          ),
          SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'add_student',
            onPressed: _navigateToStudentRegistration,
            child: Icon(Icons.person_add),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _maxDaysController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Set Maximum Attendance Days',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today),
              ),
            ),
            SizedBox(height: 15),
            ElevatedButton(
              onPressed: _saveMaxDays,
              child: Text('Save'),
            ),
            SizedBox(height: 15),
            Expanded(
              child: ListView.builder(
                itemCount: _students.length,
                itemBuilder: (context, index) {
                  final student = _students[index];
                  int maxDays = int.tryParse(_maxDaysController.text) ?? 1;
                  if (maxDays <= 0) maxDays = 1;
                  int attended = (student['attended'] as int?) ?? 0;
                  double marks = _calculateMarks(attended, maxDays);

                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(student['name'][0]),
                      ),
                      title: Text(
                        '${student['name']} | Reg: ${student['regNumber']}',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Attendance: $attended | Marks: ${marks.toStringAsFixed(2)}',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.check_circle, color: Colors.green),
                        onPressed: () =>
                            _markAttendance(student['id'], attended),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StudentRegistrationPage extends StatelessWidget {
  final Database? database;
  final Function refreshList;

  StudentRegistrationPage({required this.database, required this.refreshList});

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _regNumberController = TextEditingController();

  Future<void> _registerStudent(BuildContext context) async {
    if (_nameController.text.isNotEmpty &&
        _regNumberController.text.isNotEmpty) {
      await database?.insert('students', {
        'name': _nameController.text,
        'regNumber': _regNumberController.text
      });
      refreshList();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Register Student')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Student Name')),
            TextField(
                controller: _regNumberController,
                decoration: InputDecoration(labelText: 'Registration Number')),
            SizedBox(height: 20),
            ElevatedButton(
                onPressed: () => _registerStudent(context),
                child: Text('Register')),
          ],
        ),
      ),
    );
  }
}
