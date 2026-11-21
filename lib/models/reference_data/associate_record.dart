/// A person who can participate in debts or shared expenses.
class AssociateRecord {
  const AssociateRecord({this.id, required this.name, this.phoneNumber});

  final int? id;
  final String name;
  final String? phoneNumber;
}
