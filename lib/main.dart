import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
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

  double _calculateMarks(int attended, int maxDays) {
    if (maxDays <= 0) return 0;
    return (attended / maxDays) * 10;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Class Attendance System')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => StudentRegistrationPage(
                    database: _database, refreshList: _refreshStudentList)),
          );
          _refreshStudentList();
        },
        child: Icon(Icons.person_add),
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
              onPressed: () => setState(() {}),
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

class StudentRegistrationPage extends StatefulWidget {
  final Database? database;
  final Function refreshList;
  StudentRegistrationPage({this.database, required this.refreshList});

  @override
  _StudentRegistrationPageState createState() =>
      _StudentRegistrationPageState();
}

class _StudentRegistrationPageState extends State<StudentRegistrationPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _regNumberController = TextEditingController();

  Future<void> _registerStudent() async {
    if (_nameController.text.isNotEmpty &&
        _regNumberController.text.isNotEmpty) {
      await widget.database?.insert(
        'students',
        {'name': _nameController.text, 'regNumber': _regNumberController.text},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Student Registered Successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      widget.refreshList();
      _nameController.clear();
      _regNumberController.clear();
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
              decoration: InputDecoration(
                labelText: 'Student Name',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _regNumberController,
              decoration: InputDecoration(
                labelText: 'Registration Number',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _registerStudent,
              child: Text('Register'),
            ),
          ],
        ),
      ),
    );
  }
}
