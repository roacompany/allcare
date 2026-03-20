import SwiftUI

// MARK: - Calendar Hospital Row

struct CalendarHospitalRow: View {
    let visit: HospitalVisit

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: visit.visitType.color).opacity(0.2))
                    .frame(width: 36, height: 36)
                Image(systemName: visit.visitType.icon)
                    .font(.footnote)
                    .foregroundStyle(Color(hex: visit.visitType.color))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(visit.hospitalName)
                        .font(.subheadline.weight(.medium))
                    Text(visit.visitType.displayName)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color(hex: visit.visitType.color)))
                }
                if let purpose = visit.purpose, !purpose.isEmpty {
                    Text(purpose)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(DateFormatters.shortTime.string(from: visit.visitDate))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Calendar Vaccination Row

struct CalendarVaccinationRow: View {
    let vaccination: Vaccination

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppColors.coralColor.opacity(0.2))
                    .frame(width: 36, height: 36)
                Image(systemName: "syringe.fill")
                    .font(.footnote)
                    .foregroundStyle(AppColors.coralColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(vaccination.vaccine.displayName)
                        .font(.subheadline.weight(.medium))
                    Text("\(vaccination.doseNumber)차")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(AppColors.coralColor))
                }
                if vaccination.isCompleted {
                    Text("접종 완료")
                        .font(.caption)
                        .foregroundStyle(AppColors.successColor)
                } else if vaccination.isOverdue {
                    Text("접종 지연")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else {
                    Text("접종 예정")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            if let hospital = vaccination.hospital, !hospital.isEmpty {
                Text(hospital)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Calendar Todo Row

struct CalendarTodoRow: View {
    let todo: TodoItem
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(todo.isCompleted ? .green : AppColors.softPurpleColor)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(todo.title)
                    .font(.subheadline.weight(.medium))
                    .strikethrough(todo.isCompleted)
                    .foregroundStyle(todo.isCompleted ? .secondary : .primary)

                HStack(spacing: 6) {
                    Text(todo.category.displayName)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(AppColors.softPurpleColor))

                    if let desc = todo.description, !desc.isEmpty {
                        Text(desc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }
}

