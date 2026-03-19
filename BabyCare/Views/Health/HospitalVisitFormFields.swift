import SwiftUI
import MapKit

extension HospitalVisitFormSheet {

    func loadExisting() {
        guard let v = existingVisit else { return }
        visitType = v.visitType
        hospitalName = v.hospitalName
        department = v.department ?? ""
        doctorName = v.doctorName ?? ""
        visitDate = v.visitDate
        purpose = v.purpose ?? ""
        diagnosis = v.diagnosis ?? ""
        prescription = v.prescription ?? ""
        costText = v.cost.map { String($0) } ?? ""
        hasScheduledDate = v.scheduledDate != nil
        scheduledDate = v.scheduledDate ?? Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        hasNextVisit = v.nextVisitDate != nil
        nextVisitDate = v.nextVisitDate ?? Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        note = v.note ?? ""
    }

    func saveAndDismiss() {
        let visit = buildVisit()
        onSave(visit)

        if addToCalendar {
            let babyName = babyVM.selectedBaby?.name ?? "아기"
            Task {
                _ = await CalendarService.shared.addHospitalVisit(visit, babyName: babyName)
                if visit.nextVisitDate != nil {
                    _ = await CalendarService.shared.addNextVisit(from: visit, babyName: babyName)
                }
            }
        }

        dismiss()
    }

    func buildVisit() -> HospitalVisit {
        let babyId = babyVM.selectedBaby?.id ?? ""
        return HospitalVisit(
            id: existingVisit?.id ?? UUID().uuidString,
            babyId: babyId,
            visitType: visitType,
            hospitalName: hospitalName.trimmingCharacters(in: .whitespaces),
            department: department.isEmpty ? nil : department,
            doctorName: doctorName.isEmpty ? nil : doctorName,
            visitDate: visitDate,
            purpose: purpose.isEmpty ? nil : purpose,
            diagnosis: diagnosis.isEmpty ? nil : diagnosis,
            prescription: prescription.isEmpty ? nil : prescription,
            cost: Int(costText),
            nextVisitDate: hasNextVisit ? nextVisitDate : nil,
            scheduledDate: hasScheduledDate ? scheduledDate : nil,
            note: note.isEmpty ? nil : note,
            createdAt: existingVisit?.createdAt ?? Date()
        )
    }
}
