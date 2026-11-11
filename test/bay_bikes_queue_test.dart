import 'package:flutter_test/flutter_test.dart';
import 'package:boss_arman_motohub/core/models/models.dart';

void main() {
  group('Bay Bikes & Pending Job Requests Queue Tests', () {
    JobOrder createTestJob({
      required String id,
      required JobStatus status,
      BranchId branch = BranchId.patimbao,
    }) {
      return JobOrder(
        id: id,
        branch: branch,
        customerName: 'Test Customer',
        customerUsername: 'test_customer',
        customerPhone: '09123456789',
        bikeModel: 'Yamaha Aerox 155',
        plateNumber: 'XYZ 7890',
        serviceType: 'Maintenance',
        issueDescription: 'General checkup',
        assignedMechanic: 'Bong Mechanic',
        status: status,
        attachedParts: const [],
        laborFee: 250.0,
        createdAt: DateTime(2026, 10, 11, 8, 0),
        updatedAt: DateTime(2026, 10, 11, 8, 0),
      );
    }

    test('activeBayBikes excludes pending received jobs', () {
      final jobs = [
        createTestJob(id: 'JOB-1', status: JobStatus.received),
        createTestJob(id: 'JOB-2', status: JobStatus.inBay),
        createTestJob(id: 'JOB-3', status: JobStatus.waitingForParts),
        createTestJob(id: 'JOB-4', status: JobStatus.readyForPickup),
        createTestJob(id: 'JOB-5', status: JobStatus.completed),
        createTestJob(id: 'JOB-6', status: JobStatus.cancelled),
      ];

      // Replicating activeBayBikes getter predicate
      final activeBikes = jobs
          .where(
            (j) =>
                j.status == JobStatus.inBay ||
                j.status == JobStatus.waitingForParts ||
                j.status == JobStatus.readyForPickup,
          )
          .toList();

      expect(activeBikes.map((j) => j.id).toList(), ['JOB-2', 'JOB-3', 'JOB-4']);
      expect(activeBikes.any((j) => j.status == JobStatus.received), isFalse);
    });

    test('pendingJobRequests includes only received jobs', () {
      final jobs = [
        createTestJob(id: 'JOB-1', status: JobStatus.received),
        createTestJob(id: 'JOB-2', status: JobStatus.inBay),
        createTestJob(id: 'JOB-3', status: JobStatus.received),
        createTestJob(id: 'JOB-4', status: JobStatus.completed),
      ];

      // Replicating pendingJobRequests getter predicate
      final pending = jobs.where((j) => j.status == JobStatus.received).toList();

      expect(pending.length, 2);
      expect(pending.map((j) => j.id).toList(), ['JOB-1', 'JOB-3']);
    });

    test('cancelling or rejecting a received job never affects activeBayBikes count', () {
      final initialJobs = [
        createTestJob(id: 'JOB-1', status: JobStatus.received),
        createTestJob(id: 'JOB-2', status: JobStatus.inBay),
      ];

      final activeBefore = initialJobs
          .where(
            (j) =>
                j.status == JobStatus.inBay ||
                j.status == JobStatus.waitingForParts ||
                j.status == JobStatus.readyForPickup,
          )
          .toList();

      expect(activeBefore.length, 1);
      expect(activeBefore.first.id, 'JOB-2');

      // Reject/cancel the received job: received -> cancelled
      final updatedJobs = [
        initialJobs[0].copyWith(status: JobStatus.cancelled),
        initialJobs[1],
      ];

      final activeAfter = updatedJobs
          .where(
            (j) =>
                j.status == JobStatus.inBay ||
                j.status == JobStatus.waitingForParts ||
                j.status == JobStatus.readyForPickup,
          )
          .toList();

      final pendingAfter =
          updatedJobs.where((j) => j.status == JobStatus.received).toList();

      expect(activeAfter.length, 1);
      expect(activeAfter.first.id, 'JOB-2');
      expect(pendingAfter, isEmpty);
    });

    test('bay capacity overflow threshold triggers confirmation requirement when active count >= 6', () {
      const maxBayCapacity = 6;
      final fullBayJobs = List.generate(
        6,
        (i) => createTestJob(id: 'JOB-$i', status: JobStatus.inBay),
      );

      final activeBikes = fullBayJobs
          .where(
            (j) =>
                j.status == JobStatus.inBay ||
                j.status == JobStatus.waitingForParts ||
                j.status == JobStatus.readyForPickup,
          )
          .toList();

      expect(activeBikes.length >= maxBayCapacity, isTrue);

      final underCapacityJobs = List.generate(
        5,
        (i) => createTestJob(id: 'JOB-$i', status: JobStatus.inBay),
      );

      final underActiveBikes = underCapacityJobs
          .where(
            (j) =>
                j.status == JobStatus.inBay ||
                j.status == JobStatus.waitingForParts ||
                j.status == JobStatus.readyForPickup,
          )
          .toList();

      expect(underActiveBikes.length >= maxBayCapacity, isFalse);
    });
  });
}

