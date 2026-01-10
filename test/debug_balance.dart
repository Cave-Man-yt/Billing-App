
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:billing_app/services/database_service.dart';
import 'package:billing_app/models/customer_model.dart';
import 'package:billing_app/models/bill_model.dart';
import 'package:billing_app/models/bill_item_model.dart';

void main() async {
  // Initialize FFI
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('Reproduce Opening Balance + New Bill Issue', () async {
    final dbService = DatabaseService.instance;
    
    // 1. Create Customer with Opening Balance
    final customer = Customer(
      name: 'Test Grok',
      balance: 100.0,
      city: 'Test City',
    );
    
    print('Creating customer with balance: ${customer.balance}');
    final customerId = await dbService.createCustomer(customer);
    print('Customer created with ID: $customerId');

    // 2. Verify DB State immediately
    var fetchedCustomer = await dbService.getCustomerById(customerId);
    print('IMMEDIATE DB FETCH - Balance: ${fetchedCustomer?.balance}');
    expect(fetchedCustomer?.balance, 100.0, reason: 'Balance should be persisted');

    // 3. Verify Transaction
    final history = await dbService.getBalanceHistory(customerId);
    print('Transaction History Count: ${history.length}');
    if (history.isNotEmpty) {
      print('First Transaction Amount: ${history.first.amount}');
    }

    // 4. Simulate saveBill logic (Reading balance)
    final db = await dbService.database;
    final customerData = await db.query(
      'customers',
      where: 'id = ?',
      whereArgs: [customerId],
      limit: 1,
    );
    final prevBalance = (customerData.first['balance'] as num?)?.toDouble() ?? 0.0;
    print('saveBill READ Balance: $prevBalance');

    // 5. Calculate New Balance (Bill Total 100)
    final billTotal = 100.0;
    final amountPaid = 0.0;
    final grandTotal = prevBalance + billTotal;
    final newBalance = grandTotal - amountPaid;
    
    print('Calculated: Prev($prevBalance) + Bill($billTotal) = Grand($grandTotal). New($newBalance)');

    // 6. Create Bill
    final bill = Bill(
      billNumber: 'INV-TEST',
      customerId: customerId,
      customerName: 'Test Grok',
      subtotal: 100.0,
      total: 100.0,
      previousBalance: prevBalance,
      grandTotal: grandTotal,
      newBalance: newBalance,
      amountPaid: amountPaid,
      createdAt: DateTime.now(), 
    );
    
    // Fix: Remove 'total' and 'items' from params if incorrect, and fix BillItem constr
    // Check BillItem constructor: required quantity, price. total is calc.
    final items = [BillItem(productName: 'Item 1', quantity: 1, price: 100)];

    final billId = await dbService.createBill(bill, items);
    print('Bill created. ID: $billId');

    // 7. Update Customer Balance (saveBill does this manually)
    await dbService.updateCustomerBalance(customerId, newBalance);
    print('Updated Customer Balance to: $newBalance');

    // 8. Verify Final State
    fetchedCustomer = await dbService.getCustomerById(customerId);
    print('FINAL DB FETCH - Balance: ${fetchedCustomer?.balance}');
    
    // 9. Simulate PDF Logic
    final billFromDb = await dbService.getBillById(billId);
    final pdfDbCustomer = await dbService.getCustomerById(customerId); 
    
    double displayPrev;
    if (billFromDb?.id != null) {
       final impact = billFromDb!.total - billFromDb.amountPaid;
       displayPrev = pdfDbCustomer!.balance - impact;
       print('PDF Logic: Current(${pdfDbCustomer.balance}) - Impact($impact) = Prev($displayPrev)');
    } else {
       displayPrev = pdfDbCustomer!.balance;
    }

    expect(displayPrev, 100.0, reason: 'PDF Previous Balance should be 100');
    expect(pdfDbCustomer!.balance, 200.0, reason: 'Final DB Balance should be 200');

  });
}
