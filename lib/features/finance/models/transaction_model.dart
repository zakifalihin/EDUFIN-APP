class TransactionModel {
  final String id;
  final String title;
  final double amount;
  final String category;
  final String type;
  final DateTime createdAt;

  TransactionModel({
    required this.id, 
    required this.title, 
    required this.amount, 
    required this.category, 
    required this.type, 
    required this.createdAt
  });

  // Mengubah data JSON mentah dari Supabase menjadi Objek Dart
  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      category: json['category'] ?? 'OTHER',
      type: json['type'] ?? 'expense',
      // Mengubah format waktu Supabase menjadi format waktu lokal HP-mu
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']).toLocal() 
          : DateTime.now(),
    );
  }
}