// lib/utils/database_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:tickiting/models/user.dart';
import 'package:tickiting/models/bus.dart';
import 'package:tickiting/models/booking.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Get the application documents directory
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'rwanda_bus.db');

    return await openDatabase(
      path, 
      version: 2, 
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create users table
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        phone TEXT NOT NULL,
        gender TEXT NOT NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Create buses table
    await db.execute('''
      CREATE TABLE buses(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        departure_time TEXT NOT NULL,
        arrival_time TEXT NOT NULL,
        duration TEXT NOT NULL,
        price REAL NOT NULL,
        available_seats INTEGER NOT NULL,
        bus_type TEXT NOT NULL,
        features TEXT NOT NULL
      )
    ''');

    // Create bookings table
    await db.execute('''
      CREATE TABLE bookings(
        id TEXT PRIMARY KEY,
        user_id INTEGER NOT NULL,
        bus_id TEXT NOT NULL,
        from_location TEXT NOT NULL,
        to_location TEXT NOT NULL,
        travel_date TEXT NOT NULL,
        passengers INTEGER NOT NULL,
        seat_numbers TEXT NOT NULL,
        total_amount REAL NOT NULL,
        payment_method TEXT NOT NULL,
        payment_status TEXT NOT NULL,
        booking_status TEXT NOT NULL,
        notification_sent INTEGER NOT NULL DEFAULT 0,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(user_id) REFERENCES users(id),
        FOREIGN KEY(bus_id) REFERENCES buses(id)
      )
    ''');
    
    // Create notifications table
    await db.execute('''
      CREATE TABLE notifications(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        time TEXT NOT NULL,
        isRead INTEGER NOT NULL DEFAULT 0,
        type TEXT NOT NULL,
        recipient TEXT NOT NULL,
        userId INTEGER,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Insert some initial data
    await _insertInitialData(db);
  }
  
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add notifications table if upgrading from version 1
      await db.execute('''
        CREATE TABLE IF NOT EXISTS notifications(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          message TEXT NOT NULL,
          time TEXT NOT NULL,
          isRead INTEGER NOT NULL DEFAULT 0,
          type TEXT NOT NULL,
          recipient TEXT NOT NULL,
          userId INTEGER,
          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      
      // Add notification_sent column to bookings table if it doesn't exist
      await addNotificationSentColumnToBookings(db);
    }
  }
  
  Future<void> addNotificationSentColumnToBookings(Database db) async {
    try {
      await db.execute("ALTER TABLE bookings ADD COLUMN notification_sent INTEGER DEFAULT 0");
    } catch (e) {
      // Column might already exist
      print("Error adding notification_sent column: $e");
    }
  }

  Future<void> _insertInitialData(Database db) async {
    // Insert admin user
    await db.insert('users', {
      'name': 'Admin User',
      'email': 'admin@rwandabus.com',
      'password': 'admin123', // In a real app, this would be hashed
      'phone': '+250 789 123 456',
      'gender': 'Male',
    });

    // Insert some sample buses
    await db.insert('buses', {
      'id': 'BUS001',
      'name': 'Rwanda Express',
      'departure_time': '08:00 AM',
      'arrival_time': '10:30 AM',
      'duration': '2h 30m',
      'price': 5000,
      'available_seats': 32,
      'bus_type': 'Standard',
      'features': 'AC,WiFi,USB Charging',
    });

    await db.insert('buses', {
      'id': 'BUS002',
      'name': 'Kigali Travels',
      'departure_time': '09:30 AM',
      'arrival_time': '12:00 PM',
      'duration': '2h 30m',
      'price': 5500,
      'available_seats': 28,
      'bus_type': 'Premium',
      'features': 'AC,WiFi,USB Charging,Refreshments',
    });

    await db.insert('buses', {
      'id': 'BUS003',
      'name': 'Rwanda Shuttle',
      'departure_time': '11:00 AM',
      'arrival_time': '01:30 PM',
      'duration': '2h 30m',
      'price': 4800,
      'available_seats': 35,
      'bus_type': 'Economy',
      'features': 'AC',
    });
  }

  // User CRUD operations
  Future<int> insertUser(User user) async {
    Database db = await database;

    // Create a map from the user data
    Map<String, dynamic> userMap = user.toMap();

    if (userMap['created_at'] == null) {
      userMap['created_at'] = DateTime.now().toIso8601String();
    }

    return await db.insert('users', userMap);
  }

  Future<User?> getUser(String email, String password) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, password],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<User?> getUserByEmail(String email) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateUser(User user) async {
    Database db = await database;
    return await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<List<User>> getAllUsers() async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query('users');
    return List.generate(maps.length, (i) {
      return User.fromMap(maps[i]);
    });
  }

  // Bus CRUD operations
  Future<int> insertBus(Bus bus) async {
    Database db = await database;
    return await db.insert('buses', {
      'id': bus.id,
      'name': bus.name,
      'departure_time': bus.departureTime,
      'arrival_time': bus.arrivalTime,
      'duration': bus.duration,
      'price': bus.price,
      'available_seats': bus.availableSeats,
      'bus_type': bus.busType,
      'features': bus.features.join(','),
    });
  }

  Future<int> updateBus(Bus bus) async {
    Database db = await database;
    return await db.update(
      'buses',
      {
        'name': bus.name,
        'departure_time': bus.departureTime,
        'arrival_time': bus.arrivalTime,
        'duration': bus.duration,
        'price': bus.price,
        'available_seats': bus.availableSeats,
        'bus_type': bus.busType,
        'features': bus.features.join(','),
      },
      where: 'id = ?',
      whereArgs: [bus.id],
    );
  }

  Future<int> deleteBus(String id) async {
    Database db = await database;
    return await db.delete('buses', where: 'id = ?', whereArgs: [id]);
  }

  Future<Bus?> getBus(String id) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'buses',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Bus(
        id: maps.first['id'],
        name: maps.first['name'],
        departureTime: maps.first['departure_time'],
        arrivalTime: maps.first['arrival_time'],
        duration: maps.first['duration'],
        price: maps.first['price'],
        availableSeats: maps.first['available_seats'],
        busType: maps.first['bus_type'],
        features: maps.first['features'].split(','),
      );
    }
    return null;
  }

  Future<List<Bus>> getAllBuses() async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query('buses');
    return List.generate(maps.length, (i) {
      return Bus(
        id: maps[i]['id'],
        name: maps[i]['name'],
        departureTime: maps[i]['departure_time'],
        arrivalTime: maps[i]['arrival_time'],
        duration: maps[i]['duration'],
        price: maps[i]['price'],
        availableSeats: maps[i]['available_seats'],
        busType: maps[i]['bus_type'],
        features: maps[i]['features'].split(','),
      );
    });
  }

  // Booking CRUD operations
  Future<int> insertBooking(Booking booking) async {
    Database db = await database;

    // Create a map from the booking data
    Map<String, dynamic> bookingMap = booking.toMap();

    // Make sure created_at is set
    if (bookingMap['created_at'] == null) {
      bookingMap['created_at'] = DateTime.now().toIso8601String();
    }

    return await db.insert('bookings', bookingMap);
  }
  
  Future<User?> getUserById(int userId) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateBookingStatus(String id, String status) async {
    Database db = await database;
    return await db.update(
      'bookings',
      {'booking_status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updatePaymentStatus(String id, String status) async {
    Database db = await database;
    return await db.update(
      'bookings',
      {'payment_status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Booking>> getUserBookings(int userId) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'bookings',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return List.generate(maps.length, (i) {
      return Booking.fromMap(maps[i]);
    });
  }

  Future<List<Booking>> getAllBookings() async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query('bookings');
    return List.generate(maps.length, (i) {
      return Booking.fromMap(maps[i]);
    });
  }

  // Notification operations
  Future<int> insertNotification(Map<String, dynamic> notification) async {
    Database db = await database;
    return await db.insert('notifications', notification);
  }
  
  Future<List<Map<String, dynamic>>> getNotifications({
    String? recipient,
    int? userId,
  }) async {
    Database db = await database;
    String? whereClause;
    List<dynamic>? whereArgs;
    
    if (recipient != null && userId != null) {
      whereClause = 'recipient = ? AND userId = ?';
      whereArgs = [recipient, userId];
    } else if (recipient != null) {
      whereClause = 'recipient = ?';
      whereArgs = [recipient];
    } else if (userId != null) {
      whereClause = 'userId = ?';
      whereArgs = [userId];
    }
    
    return await db.query(
      'notifications',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'time DESC',
    );
  }
  
  Future<int> markNotificationAsRead(int id) async {
    Database db = await database;
    return await db.update(
      'notifications',
      {'isRead': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  Future<int> markAllNotificationsAsRead({String? recipient, int? userId}) async {
    Database db = await database;
    String? whereClause;
    List<dynamic>? whereArgs;
    
    if (recipient != null && userId != null) {
      whereClause = 'recipient = ? AND userId = ?';
      whereArgs = [recipient, userId];
    } else if (recipient != null) {
      whereClause = 'recipient = ?';
      whereArgs = [recipient];
    } else if (userId != null) {
      whereClause = 'userId = ?';
      whereArgs = [userId];
    }
    
    return await db.update(
      'notifications',
      {'isRead': 1},
      where: whereClause,
      whereArgs: whereArgs,
    );
  }
  
  Future<int> deleteNotification(int id) async {
    Database db = await database;
    return await db.delete(
      'notifications',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  Future<int> getUnreadNotificationsCount({String? recipient, int? userId}) async {
    Database db = await database;
    String? whereClause;
    List<dynamic>? whereArgs;
    
    if (recipient != null && userId != null) {
      whereClause = 'recipient = ? AND userId = ? AND isRead = ?';
      whereArgs = [recipient, userId, 0];
    } else if (recipient != null) {
      whereClause = 'recipient = ? AND isRead = ?';
      whereArgs = [recipient, 0];
    } else if (userId != null) {
      whereClause = 'userId = ? AND isRead = ?';
      whereArgs = [userId, 0];
    } else {
      whereClause = 'isRead = ?';
      whereArgs = [0];
    }
    
    List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM notifications WHERE $whereClause',
      whereArgs,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
  
  // Update booking notification status
  Future<int> updateBookingNotificationStatus(String bookingId, bool sent) async {
    Database db = await database;
    return await db.update(
      'bookings',
      {'notification_sent': sent ? 1 : 0},
      where: 'id = ?',
      whereArgs: [bookingId],
    );
  }
  
  // Add notification_sent column to bookings table if it doesn't exist
  Future<void> addNotificationSentColumnIfNeeded() async {
    final db = await database;
    
    // Check if the notification_sent column exists in the bookings table
    var tableInfo = await db.rawQuery("PRAGMA table_info(bookings)");
    bool hasColumn = tableInfo.any((column) => column['name'] == 'notification_sent');
    
    if (!hasColumn) {
      await addNotificationSentColumnToBookings(db);
    }
  }

  // Additional utility methods

  // Get booking count by status
  Future<int> getBookingCountByStatus(String status) async {
    Database db = await database;
    List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM bookings WHERE booking_status = ?',
      [status],
    );
    return result.first['count'];
  }

  // Get total revenue
  Future<double> getTotalRevenue() async {
    Database db = await database;
    List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT SUM(total_amount) as total FROM bookings WHERE payment_status = ?',
      ['Confirmed'],
    );
    return result.first['total'] ?? 0.0;
  }

  // Get revenue by date range
  Future<double> getRevenueByDateRange(String startDate, String endDate) async {
    Database db = await database;
    List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT SUM(total_amount) as total FROM bookings WHERE payment_status = ? AND created_at BETWEEN ? AND ?',
      ['Confirmed', startDate, endDate],
    );
    return result.first['total'] ?? 0.0;
  }

  // Get bookings by date
  Future<List<Booking>> getBookingsByDate(String date) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'bookings',
      where: 'travel_date = ?',
      whereArgs: [date],
    );
    return List.generate(maps.length, (i) {
      return Booking.fromMap(maps[i]);
    });
  }

  // Delete all data (for testing purposes)
  Future<void> deleteAllData() async {
    Database db = await database;
    await db.delete('bookings');
    await db.delete('buses');
    await db.delete('notifications');
    await db.delete('users');
  }
}