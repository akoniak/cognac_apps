//
//  NewReportView.swift
//  Community Status App
//
//  Form for submitting a new status report
//

import SwiftUI

struct NewReportView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = NewReportViewModel()
    
    var body: some View {
        NavigationStack {
            Form {
                // Category selection
                Section("What are you reporting?") {
                    Picker("Category", selection: $viewModel.selectedCategory) {
                        ForEach(ReportCategory.allCases, id: \.self) { category in
                            Label(category.displayName, systemImage: category.iconName)
                                .tag(category)
                        }
                    }
                    .pickerStyle(.wheel)
                }

                // Road selection — used for all categories
                Section("Select Road") {
                    Picker("Road", selection: $viewModel.selectedRoadID) {
                        Text("Select a road...").tag(nil as String?)
                        ForEach(viewModel.availableRoads) { road in
                            Text(road.name).tag(road.id as String?)
                        }
                    }
                }
                
                // Optional note
                Section("Additional Details (Optional)") {
                    TextField("Add a note", text: $viewModel.note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("New Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        Task {
                            await viewModel.submitReport()
                            if viewModel.submitSuccess {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.canSubmit || viewModel.isSubmitting)
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
            .overlay {
                if viewModel.isSubmitting {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(.white)
                            Text("Submitting report...")
                                .foregroundStyle(.white)
                        }
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
}

#Preview {
    NewReportView()
}
