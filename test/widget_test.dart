import 'package:flutter_test/flutter_test.dart';
import 'package:untitled/main.dart';
import 'package:untitled/models/user_model.dart';
import 'package:untitled/models/building_model.dart';
import 'package:untitled/core/constants/app_constants.dart';

void main() {
  test('User Model serialization test', () {
    final user = UserModel(
      id: '123',
      name: 'Test Student',
      email: 'student@annauniv.edu',
      role: 'student',
    );

    expect(user.isNaiveUser, true);
    expect(user.isEngineer, false);
    expect(user.isAdmin, false);
    expect(user.roleDisplayName, 'Student');
  });

  test('Building Model serialization test', () {
    final building = BuildingModel.fromJson({
      'id': 1,
      'name': 'Main Admin Block',
      'code': 'ADMIN-01',
    });

    expect(building.name, 'Main Admin Block');
    expect(building.code, 'ADMIN-01');
  });

  test('AppConstants validity', () {
    expect(AppConstants.issueTypes.contains('Bathroom Related Issues'), true);
    expect(AppConstants.severities.contains('High'), true);
    expect(AppConstants.statuses.contains('Closed Successfully'), true);
  });

  testWidgets('App smoke test initializes AuthGate', (WidgetTester tester) async {
    await tester.pumpWidget(const GrievanceRedressalApp());
    expect(find.byType(GrievanceRedressalApp), findsOneWidget);
  });
}
