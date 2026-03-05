class PsvInsuranceData {
  final String? policyNumber;
  final String? insurerName;
  final String? insuredName;
  final String? vehiclePlate;
  final String? startDate;
  final String? expiryDate;

  const PsvInsuranceData({
    this.policyNumber,
    this.insurerName,
    this.insuredName,
    this.vehiclePlate,
    this.startDate,
    this.expiryDate,
  });

  Map<String, dynamic> toMap() => {
    'policy_number': policyNumber,
    'insurer_name': insurerName,
    'insured_name': insuredName,
    'vehicle_plate': vehiclePlate,
    'start_date': startDate,
    'expiry_date': expiryDate,
  };
}