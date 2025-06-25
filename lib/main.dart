import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:async';
import 'dart:io';

void main() {
  runApp(const ReservationApp());
}

class ReservationApp extends StatelessWidget {
  const ReservationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reservation App',
      home: const ReservationPage(),
    );
  }
}

class Reservation {
  final int? id;
  final String userName;
  final DateTime dateTime;

  Reservation({this.id, required this.userName, required this.dateTime});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userName': userName,
      'dateTime': dateTime.toIso8601String(),
    };
  }

  static Reservation fromMap(Map<String, dynamic> map) {
    return Reservation(
      id: map['id'],
      userName: map['userName'],
      dateTime: DateTime.parse(map['dateTime']),
    );
  }
}

class DatabaseHelper {
  static const _dbName = 'reservations.db';
  static const _tableName = 'reservations';
  static Database? _db;

  static Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/$_dbName';
    return openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE $_tableName(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            userName TEXT,
            dateTime TEXT
          )
        ''');
      },
    );
  }

  static Future<int> insert(Reservation r) async {
    final database = await db;
    return database.insert(_tableName, r.toMap());
  }

  static Future<List<Reservation>> getAll() async {
    final database = await db;
    final List<Map<String, dynamic>> maps = await database.query(_tableName);
    return List.generate(maps.length, (i) => Reservation.fromMap(maps[i]));
  }
}

class ReservationPage extends StatefulWidget {
  const ReservationPage({super.key});

  @override
  State<ReservationPage> createState() => _ReservationPageState();
}

class _ReservationPageState extends State<ReservationPage> {
  final _nameController = TextEditingController();
  DateTime? _selectedDate;
  List<Reservation> _reservations = [];

  @override
  void initState() {
    super.initState();
    _loadReservations();
  }

  Future<void> _loadReservations() async {
    final data = await DatabaseHelper.getAll();
    setState(() {
      _reservations = data;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (time != null) {
        setState(() {
          _selectedDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_nameController.text.isEmpty || _selectedDate == null) return;
    final r = Reservation(userName: _nameController.text, dateTime: _selectedDate!);
    await DatabaseHelper.insert(r);
    _nameController.clear();
    _selectedDate = null;
    await _loadReservations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reservation')), 
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(_selectedDate != null
                      ? _selectedDate.toString()
                      : 'Select Date/Time'),
                ),
                IconButton(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today),
                ),
              ],
            ),
            ElevatedButton(
              onPressed: _submit,
              child: const Text('Reserve'),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _reservations.length,
                itemBuilder: (context, index) {
                  final r = _reservations[index];
                  return ListTile(
                    title: Text(r.userName),
                    subtitle: Text(r.dateTime.toString()),
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
