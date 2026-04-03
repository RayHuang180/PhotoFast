import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    
    // 新增：用來追蹤是否正在上傳中
    @State private var isUploading: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack {
                // 圖片預覽區塊
                if selectedImages.isEmpty {
                    Text("尚未選擇照片")
                        .foregroundColor(.secondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(0..<selectedImages.count, id: \.self) { index in
                                Image(uiImage: selectedImages[index])
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 120, height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(radius: 3)
                            }
                        }
                        .padding()
                    }
                }
                
                Spacer()
                
                // 上傳按鈕
                Button(action: {
                    print("準備上傳 \(selectedImages.count) 張照片")
                    Task {
                        isUploading = true // 開始上傳，鎖定按鈕
                        await uploadSelectedPhotos()
                        isUploading = false // 上傳結束，解鎖按鈕
                    }
                }) {
                    // 動態顯示按鈕文字
                    Group {
                        if isUploading {
                            Text("上傳中請稍候...")
                        } else if selectedItems.count != selectedImages.count {
                            Text("照片載入中 (\(selectedImages.count)/\(selectedItems.count))...")
                        } else {
                            Text("上傳至電腦")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    // 狀態判斷：可以上傳時顯示藍色，否則顯示灰色
                    .background((selectedItems.count == selectedImages.count && !selectedImages.isEmpty && !isUploading) ? Color.blue : Color.gray)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                // 禁用條件：沒選照片、照片還沒載入完，或者「正在上傳中」時，按鈕反灰不准按
                .disabled(selectedImages.isEmpty || selectedItems.count != selectedImages.count || isUploading)
                .padding(.bottom)
            }
            .navigationTitle("PhotoFast")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    PhotosPicker(
                        selection: $selectedItems,
                        maxSelectionCount: 0,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.title2)
                    }
                    // 禁用相簿按鈕，防止上傳途中更改圖片
                    .disabled(isUploading)
                    .onChange(of: selectedItems) { oldValue, newItems in
                        loadImages(from: newItems)
                    }
                }
            }
        }
    }
    
    // 【優化】使用 async/await 來載入圖片，保證順序且語法更簡潔
    private func loadImages(from items: [PhotosPickerItem]) {
        selectedImages.removeAll()
        
        Task {
            for item in items {
                do {
                    // 使用非同步方式讀取 Data
                    if let data = try await item.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        // 切回 Main Thread 更新 UI
                        await MainActor.run {
                            selectedImages.append(uiImage)
                        }
                    }
                } catch {
                    print("載入圖片失敗: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func uploadSelectedPhotos() async {
        let serverURLString = "http://192.168.11.56:5000/upload"
        guard let url = URL(string: serverURLString) else { return }
        
        for (index, image) in selectedImages.enumerated() {
            guard let imageData = image.jpegData(compressionQuality: 0.8) else { continue }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            
            let boundary = "Boundary-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            var body = Data()
            let filename = "photo_\(Int(Date().timeIntervalSince1970))_\(index).jpg"
            
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"photo\"; filename=\"\(filename)\"\r\n")
            body.append("Content-Type: image/jpeg\r\n\r\n")
            body.append(imageData)
            body.append("\r\n")
            body.append("--\(boundary)--\r\n")
            
            request.httpBody = body
            
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    print("✅ 第 \(index + 1)/\(selectedImages.count) 張上傳成功！")
                } else {
                    print("❌ 第 \(index + 1)/\(selectedImages.count) 張上傳失敗，狀態碼錯誤。")
                }
            } catch {
                print("❌ 第 \(index + 1)/\(selectedImages.count) 張上傳發生錯誤: \(error.localizedDescription)")
            }
        }
        
        print("🎉 全部照片處理完畢！")
    }
}

extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            self.append(data)
        }
    }
}
