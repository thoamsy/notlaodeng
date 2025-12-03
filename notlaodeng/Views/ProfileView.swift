//
//  ProfileView.swift
//  notlaodeng
//
//  用户档案视图
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    @ObserveInjection var forceRedraw

    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @State private var showingEditProfile = false

    var currentProfile: UserProfile? {
        profiles.first
    }

    var body: some View {
        NavigationStack {
            Group {
                if let profile = currentProfile {
                    profileContent(profile)
                } else {
                    createProfilePrompt
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                if currentProfile != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingEditProfile = true
                        } label: {
                            Text("Edit")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingEditProfile) {
                if let profile = currentProfile {
                    EditProfileView(profile: profile)
                } else {
                    EditProfileView(profile: nil)
                }
            }
        }
        .id(forceRedraw)
        .eraseToAnyView()
    }

    private var createProfilePrompt: some View {
        ContentUnavailableView {
            Label("No Profile", systemImage: "person.circle")
        } description: {
            Text("Create your profile to get personalized health insights.")
        } actions: {
            Button("Create Profile") {
                showingEditProfile = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func profileContent(_ profile: UserProfile) -> some View {
        List {
            Section {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.name)
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("\(profile.age) years old, \(profile.gender.rawValue)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }

            Section("Basic Info") {
                LabeledContent("Birth Date", value: profile.birthDate.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("Gender", value: profile.gender.rawValue)

                if let bloodType = profile.bloodType {
                    LabeledContent("Blood Type", value: bloodType.rawValue)
                }

                if let height = profile.height {
                    LabeledContent("Height", value: "\(Int(height)) cm")
                }

                if let weight = profile.weight {
                    LabeledContent("Weight", value: "\(Int(weight)) kg")
                }

                if let bmi = profile.bmi {
                    LabeledContent("BMI", value: String(format: "%.1f", bmi))
                }
            }

            if !profile.medicalHistory.isEmpty {
                Section("Medical History") {
                    ForEach(profile.medicalHistory, id: \.self) { item in
                        Text(item)
                    }
                }
            }

            if !profile.allergies.isEmpty {
                Section("Allergies") {
                    ForEach(profile.allergies, id: \.self) { item in
                        Text(item)
                    }
                }
            }
        }
    }
}

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let profile: UserProfile?

    @State private var name: String = ""
    @State private var birthDate: Date = Date()
    @State private var gender: Gender = .male
    @State private var bloodType: BloodType?
    @State private var height: String = ""
    @State private var weight: String = ""

    var isEditing: Bool { profile != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Info") {
                    TextField("Name", text: $name)
                    DatePicker("Birth Date", selection: $birthDate, displayedComponents: .date)

                    Picker("Gender", selection: $gender) {
                        ForEach(Gender.allCases, id: \.self) { gender in
                            Text(gender.rawValue).tag(gender)
                        }
                    }

                    Picker("Blood Type", selection: $bloodType) {
                        Text("Unknown").tag(nil as BloodType?)
                        ForEach(BloodType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type as BloodType?)
                        }
                    }
                }

                Section("Measurements") {
                    HStack {
                        TextField("Height", text: $height)
                            .keyboardType(.numberPad)
                        Text("cm")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        TextField("Weight", text: $weight)
                            .keyboardType(.numberPad)
                        Text("kg")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Profile" : "Create Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProfile()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                if let profile = profile {
                    name = profile.name
                    birthDate = profile.birthDate
                    gender = profile.gender
                    bloodType = profile.bloodType
                    if let h = profile.height {
                        height = String(Int(h))
                    }
                    if let w = profile.weight {
                        weight = String(Int(w))
                    }
                }
            }
        }
    }

    private func saveProfile() {
        if let profile = profile {
            // 更新现有 profile
            profile.name = name
            profile.birthDate = birthDate
            profile.gender = gender
            profile.bloodType = bloodType
            profile.height = Double(height)
            profile.weight = Double(weight)
        } else {
            // 创建新 profile
            let newProfile = UserProfile(
                name: name,
                birthDate: birthDate,
                gender: gender,
                bloodType: bloodType,
                height: Double(height),
                weight: Double(weight)
            )
            modelContext.insert(newProfile)
        }
        dismiss()
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: UserProfile.self, inMemory: true)
}

