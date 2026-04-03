import SwiftUI
import PhotosUI

struct ContentView: View {
    // 儲存使用者在 PhotosPicker 中選取的項目
    @State private var selectedItems: [PhotosPickerItem] = []
    // 儲存轉換後的實際圖片，用於畫面預覽與後續上傳
    @State private var selectedImages: [UIImage] = []
   
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
                        await uploadSelectedPhotos()
                    }
                }) {
                    // 動態顯示按鈕文字：如果還在載入中，就顯示進度
                    Text(selectedItems.count == selectedImages.count ? "上傳至電腦" : "照片處理中 (\(selectedImages.count)/\(selectedItems.count))...")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        // 狀態判斷：數量相符且不為空時才顯示藍色，否則顯示灰色
                        .background(selectedItems.count == selectedImages.count && !selectedImages.isEmpty ? Color.blue : Color.gray)
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
                // 禁用條件：沒選照片，或者「已選取數量」不等於「已載入預覽圖數量」時，按鈕反灰不准按
                .disabled(selectedImages.isEmpty || selectedItems.count != selectedImages.count)
                .padding(.bottom)
            }
            .navigationTitle("PhotoFast")
            .toolbar {
                // 導覽列右上角的相簿按鈕
                ToolbarItem(placement: .navigationBarTrailing) {
                    PhotosPicker(
                        selection: $selectedItems,
                        maxSelectionCount: 0, // 設定為 0 代表可以多選，不限數量
                        matching: .images,    // 只允許選擇圖片
                        photoLibrary: .shared()
                    ) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.title2)
                    }
                    // 當選取的項目發生變化時，觸發載入圖片的動作
                    .onChange(of: selectedItems) { oldValue, newItems in
                        loadImages(from: newItems)
                    }
                }
            }
        }
    }
   
    // 將 PhotosPickerItem 轉換為實際的 UIImage
    private func loadImages(from items: [PhotosPickerItem]) {
        // 清空舊的選擇
        selectedImages.removeAll()
       
        for item in items {
            // 請求圖片的二進位資料 (Data)
            item.loadTransferable(type: Data.self) { result in
                switch result {
                case .success(let data?):
                    // 將 Data 轉換為 UIImage 並更新到畫面上 (需回到主執行緒)
                    if let uiImage = UIImage(data: data) {
                        DispatchQueue.main.async {
                            selectedImages.append(uiImage)
                        }
                    }
                case .success(nil):
                    print("無法取得圖片資料")
                case .failure(let error):
                    print("載入圖片失敗: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // 在函數名稱後加上 async
    private func uploadSelectedPhotos() async {
        let serverURLString = "http://192.168.11.56:5000/upload"
        guard let url = URL(string: serverURLString) else { return }
       
        for (index, image) in selectedImages.enumerated() {
            // 轉為 JPEG
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
           
            // 【關鍵修改】使用 try await 來「等待」這張照片上傳完畢
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

#Preview {
    ContentView()
}

extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) { self.append(data)
        }
    }
}
