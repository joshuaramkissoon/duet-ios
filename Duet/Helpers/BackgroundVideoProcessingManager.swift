//
//  BackgroundVideoProcessingManager.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 24/05/2025.
//

import Foundation
import Firebase
import FirebaseAuth

class VideoProcessingManager: ObservableObject {
   private var listener: ListenerRegistration?
   private let db = Firestore.firestore()
   private let dateIdeaVM: DateIdeaViewModel
   
   init(dateIdeaVM: DateIdeaViewModel) {
       self.dateIdeaVM = dateIdeaVM
   }
   
   func startListening() {
       guard let userId = Auth.auth().currentUser?.uid else { return }
       
       listener = db.collection("users")
                   .document(userId)
                   .collection("pendingVideos")
                   .addSnapshotListener { [weak self] snapshot, error in
                       if let error = error {
                           print("❌ Listener error: \(error)")
                           return
                       }
                       
                       guard let documentChanges = snapshot?.documentChanges else { return }
                       
                       // Only process newly added documents (from share extension)
                       for change in documentChanges {
                           if change.type == .added {
                               let document = change.document
                               if let videoURL = document.data()["videoURL"] as? String {
                                   self?.processVideoImmediately(documentId: document.documentID, videoURL: videoURL)
                               }
                           }
                       }
                   }
   }
   
   func stopListening() {
       listener?.remove()
       listener = nil
   }
   
   private func processVideoImmediately(documentId: String, videoURL: String) {
       print("🎥 Processing new video from share extension: \(videoURL)")
       
       // Trigger DateIdeaViewModel to process the video
       DispatchQueue.main.async { [weak self] in
           self?.dateIdeaVM.urlText = videoURL
           self?.dateIdeaVM.summariseVideo()
       }
       
       // Clean up the Firestore document since we don't need it anymore
       deleteProcessedDocument(documentId: documentId)
   }
   
   private func deleteProcessedDocument(documentId: String) {
       guard let userId = Auth.auth().currentUser?.uid else { return }
       
       db.collection("users")
         .document(userId)
         .collection("pendingVideos")
         .document(documentId)
         .delete { error in
             if let error = error {
                 print("⚠️ Failed to delete processed document: \(error)")
             } else {
                 print("✅ Cleaned up processed document: \(documentId)")
             }
         }
   }
   
   deinit {
       stopListening()
   }
}
