import SwiftUI
import Photos
import ImageIO
import CoreLocation
import MapKit
import UIKit

/// Full-screen photo information overlay.
struct AssetInfoPanel: View {
    let asset: PHAsset
    var onClose: () -> Void

    @State private var properties: [String: Any] = [:]
    @State private var fileName: String = ""
    @State private var fileSizeText: String = ""
    @State private var placeName: String = ""
    @State private var areaName: String = ""
    @State private var elevationText: String = ""
    @State private var pins: [MapPoint] = []
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var isLoading = true
    @State private var dragOffset: CGFloat = 0
    @State private var backgroundImage: UIImage?

    private struct MapPoint: Identifiable {
        let id = UUID()
        let coordinate: CLLocationCoordinate2D
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Group {
                    if let backgroundImage {
                        Image(uiImage: backgroundImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                            .blur(radius: 24)
                            .overlay(Color.black.opacity(0.55))
                    } else {
                        Theme.background
                    }
                }
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    headerArea(topInset: max(geo.safeAreaInsets.top, 52))

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(relativeDateText)
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text(dateText)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .padding(.top, 12)

                            dashedDivider

                            sectionTitle("照片资讯", icon: "camera.fill")

                            if !cameraDeviceText.isEmpty {
                                HStack(alignment: .firstTextBaseline, spacing: 14) {
                                    Text("设备")
                                        .foregroundColor(Theme.textSecondary)
                                    Spacer(minLength: 0)
                                    Text(cameraDeviceText)
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.trailing)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .font(.system(size: 16, weight: .semibold))
                            }

                            if !cameraMetrics.isEmpty {
                                HStack(spacing: 8) {
                                    ForEach(Array(cameraMetrics.enumerated()), id: \.offset) { _, metric in
                                        metricTile(value: metric.value, label: metric.label)
                                    }
                                }
                            }

                            if !extraCameraRows.isEmpty {
                                outlinedRows(extraCameraRows)
                            }

                            VStack(spacing: 0) {
                                metadataRow("文件名称", fileName.isEmpty ? "读取中…" : fileName)
                                divider
                                metadataRow("解析度", "\(asset.pixelWidth) × \(asset.pixelHeight)")
                                if asset.mediaType == .video {
                                    divider
                                    metadataRow("时长", durationText)
                                }
                                if !fileSizeText.isEmpty {
                                    divider
                                    metadataRow("文件大小", fileSizeText)
                                }
                            }

                            if !pins.isEmpty {
                                dashedDivider
                                sectionTitle("拍摄位置", icon: "location.fill")
                                locationCard
                            }

                            if isLoading {
                                ProgressView().tint(.white.opacity(0.6))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, max(geo.safeAreaInsets.bottom, 34) + 28)
                    }
                }
                .offset(y: max(0, dragOffset))
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onAppear {
            load()
            loadBackground()
        }
    }

    /// The header and content remain over the full-screen blurred photo.
    private func headerArea(topInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.white.opacity(0.22))
                .frame(width: 36, height: 4)
                .padding(.top, 10)

            HStack {
                Text(asset.mediaType == .video ? "视频详情" : "照片详情")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }
                .floatingGlass(Circle())
                .accessibilityLabel("收起详情")
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
            .padding(.bottom, 4)
        }
        .padding(.top, topInset)
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 90 {
                        onClose()
                    }
                    dragOffset = 0
                }
        )
    }

    // MARK: - Location

    private var locationCard: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                Map(coordinateRegion: $region,
                    interactionModes: [],
                    showsUserLocation: false,
                    annotationItems: pins) { pin in
                    MapMarker(coordinate: pin.coordinate, tint: Theme.success)
                }
                .frame(height: 148)

                if !elevationText.isEmpty {
                    Text(elevationText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.black.opacity(0.85))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.white.opacity(0.92)))
                        .padding(10)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(placeName.isEmpty ? "未知地点" : placeName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Text(areaName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, 2)
            .padding(.top, 10)
            .padding(.bottom, 12)

            if let coordinateText {
                divider
                metadataRow("坐标", coordinateText)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.black.opacity(0.28)))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
        )
    }

    private func loadBackground() {
        let target = ImageStore.target(for: UIScreen.main.bounds.size)
        ImageStore.shared.load(for: asset, target: target) { image in
            backgroundImage = image
        }
    }

    private var coordinateText: String? {
        guard let coordinate = pins.first?.coordinate else { return nil }
        return String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
    }

    // MARK: - Cards

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.16))
            .frame(height: 1)
    }

    private var dashedDivider: some View {
        GeometryReader { geometry in
            Path { path in
                path.move(to: CGPoint(x: 0, y: geometry.size.height / 2))
                path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height / 2))
            }
            .stroke(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [1, 3]))
        }
        .frame(height: 1)
    }

    private func sectionTitle(_ text: String, icon: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
            Text(text)
                .font(.system(size: 17, weight: .bold, design: .rounded))
        }
        .foregroundColor(Theme.textSecondary)
        .padding(.top, 2)
    }

    private func metadataRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Theme.textTertiary)
                .frame(width: 4, height: 4)
                .padding(.top, 8)
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .padding(.vertical, 11)
    }

    private func metricTile(value: String, label: String) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 54)
        .padding(.vertical, 4)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
        )
    }

    private func outlinedRows(_ rows: [(String, String)]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, item in
                if index > 0 { divider }
                HStack(alignment: .top, spacing: 12) {
                    Text(item.0)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                    Spacer(minLength: 8)
                    Text(item.1)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                .padding(.vertical, 10)
            }
        }
        .padding(.horizontal, 14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.black.opacity(0.24)))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Formatting

    private var dateText: String {
        guard let date = photoDate else { return "未知" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 EEEE HH:mm"
        return formatter.string(from: date)
    }

    private var relativeDateText: String {
        guard let date = photoDate else { return "照片" }
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date, to: Date())
        if let years = components.year, years >= 1 { return "\(years) 年前" }
        if let months = components.month, months >= 1 { return "\(months) 个月前" }
        if let days = components.day, days >= 1 { return "\(days) 天前" }
        return "今天"
    }

    private var photoDate: Date? {
        if let date = asset.creationDate { return date }
        let value = stringValue(exif[kCGImagePropertyExifDateTimeOriginal as String])
        guard !value.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: value)
    }

    private var durationText: String {
        let total = Int(asset.duration.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private var exif: [String: Any] {
        properties[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
    }

    private var exifAux: [String: Any] {
        properties[kCGImagePropertyExifAuxDictionary as String] as? [String: Any] ?? [:]
    }

    private var tiff: [String: Any] {
        properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
    }

    private var cameraDeviceText: String {
        let make = stringValue(tiff[kCGImagePropertyTIFFMake as String])
        let model = stringValue(tiff[kCGImagePropertyTIFFModel as String])
        if make.isEmpty { return model }
        if model.isEmpty { return make }
        if model.lowercased().hasPrefix(make.lowercased()) { return model }
        return "\(make) \(model)"
    }

    private var cameraMetrics: [(label: String, value: String)] {
        var metrics: [(label: String, value: String)] = []
        if let fNumber = numberValue(exif[kCGImagePropertyExifFNumber as String]), fNumber > 0 {
            metrics.append((label: "光圈", value: String(format: "f/%.1f", fNumber)))
        }
        if let exposure = numberValue(exif[kCGImagePropertyExifExposureTime as String]), exposure > 0 {
            let shutter = exposure < 1
                ? "1/\(Int((1 / exposure).rounded())) s"
                : String(format: "%.2g s", exposure)
            metrics.append((label: "快门", value: shutter))
        }
        if let iso = firstNumber(exif[kCGImagePropertyExifISOSpeedRatings as String]) {
            metrics.append((label: "感光度", value: "ISO \(Int(iso.rounded()))"))
        }
        if let focal = numberValue(exif[kCGImagePropertyExifFocalLength as String]), focal > 0 {
            metrics.append((label: "焦距", value: String(format: "%.0f mm", focal)))
        }
        return metrics
    }

    private var extraCameraRows: [(String, String)] {
        var rows: [(String, String)] = []
        let lensMake = stringValue(exif[kCGImagePropertyExifLensMake as String])
        let lensModel = stringValue(exif[kCGImagePropertyExifLensModel as String])
        let auxiliaryLensModel = stringValue(exifAux[kCGImagePropertyExifAuxLensModel as String])
        let lens = [lensMake, lensModel]
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { values, value in
                if !values.contains(where: { $0.localizedCaseInsensitiveCompare(value) == .orderedSame }) {
                    values.append(value)
                }
            }
            .joined(separator: " ")
        append("镜头", lens.isEmpty ? auxiliaryLensModel : lens, to: &rows)

        if let equivalent = numberValue(exif[kCGImagePropertyExifFocalLenIn35mmFilm as String]), equivalent > 0 {
            rows.append(("等效焦距", "\(Int(equivalent.rounded())) mm"))
        }
        if let bias = numberValue(exif[kCGImagePropertyExifExposureBiasValue as String]) {
            rows.append(("曝光补偿", String(format: "%+.1f EV", bias)))
        }
        if let program = numberValue(exif[kCGImagePropertyExifExposureProgram as String]) {
            rows.append(("曝光程序", exposureProgram(Int(program))))
        }
        if let mode = numberValue(exif[kCGImagePropertyExifExposureMode as String]) {
            rows.append(("曝光模式", exposureMode(Int(mode))))
        }
        if let mode = numberValue(exif[kCGImagePropertyExifMeteringMode as String]) {
            rows.append(("测光模式", meteringMode(Int(mode))))
        }
        if let flash = numberValue(exif[kCGImagePropertyExifFlash as String]) {
            rows.append(("闪光灯", (Int(flash) & 1) == 1 ? "已闪光" : "未闪光"))
        }
        if let whiteBalance = numberValue(exif[kCGImagePropertyExifWhiteBalance as String]) {
            rows.append(("白平衡", Int(whiteBalance) == 0 ? "自动" : "手动"))
        }
        if let lightSource = numberValue(exif[kCGImagePropertyExifLightSource as String]) {
            rows.append(("光源", lightSourceName(Int(lightSource))))
        }
        if let scene = numberValue(exif[kCGImagePropertyExifSceneCaptureType as String]) {
            rows.append(("场景", sceneName(Int(scene))))
        }
        if let zoom = numberValue(exif[kCGImagePropertyExifDigitalZoomRatio as String]), zoom > 0, zoom != 1 {
            rows.append(("数码变焦", String(format: "%.1f×", zoom)))
        }
        append("拍摄软件", stringValue(tiff[kCGImagePropertyTIFFSoftware as String]), to: &rows)
        append("作者", stringValue(tiff[kCGImagePropertyTIFFArtist as String]), to: &rows)
        append("版权", stringValue(tiff[kCGImagePropertyTIFFCopyright as String]), to: &rows)

        if let colorSpace = numberValue(exif[kCGImagePropertyExifColorSpace as String]) {
            rows.append(("色彩空间", Int(colorSpace) == 1 ? "sRGB" : "未校准色彩空间"))
        }
        if let brightness = numberValue(exif[kCGImagePropertyExifBrightnessValue as String]) {
            rows.append(("亮度", String(format: "%.1f EV", brightness)))
        }
        if let contrast = numberValue(exif[kCGImagePropertyExifContrast as String]) {
            rows.append(("对比度", renderingValue(Int(contrast))))
        }
        if let saturation = numberValue(exif[kCGImagePropertyExifSaturation as String]) {
            rows.append(("饱和度", renderingValue(Int(saturation))))
        }
        if let sharpness = numberValue(exif[kCGImagePropertyExifSharpness as String]) {
            rows.append(("锐度", renderingValue(Int(sharpness))))
        }
        append("相机持有人", stringValue(exif[kCGImagePropertyExifCameraOwnerName as String]), to: &rows)
        return rows
    }

    private func append(_ title: String, _ value: String, to rows: inout [(String, String)]) {
        guard !value.isEmpty else { return }
        rows.append((title, value))
    }

    private func stringValue(_ value: Any?) -> String {
        (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func numberValue(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let number = value as? Double { return number }
        if let number = value as? Int { return Double(number) }
        return nil
    }

    private func firstNumber(_ value: Any?) -> Double? {
        if let values = value as? [NSNumber] { return values.first?.doubleValue }
        if let values = value as? [Int] { return values.first.map { Double($0) } }
        return numberValue(value)
    }

    private func exposureProgram(_ value: Int) -> String {
        switch value {
        case 1: return "手动"
        case 2: return "程序自动"
        case 3: return "光圈优先"
        case 4: return "快门优先"
        case 5: return "创意"
        case 6: return "运动"
        case 7: return "人像"
        case 8: return "风景"
        default: return "其他"
        }
    }

    private func exposureMode(_ value: Int) -> String {
        switch value {
        case 0: return "自动曝光"
        case 1: return "手动曝光"
        case 2: return "自动包围曝光"
        default: return "其他"
        }
    }

    private func lightSourceName(_ value: Int) -> String {
        switch value {
        case 1: return "日光"
        case 2: return "荧光灯"
        case 3: return "白炽灯"
        case 4: return "闪光灯"
        case 9: return "晴天"
        case 10: return "阴天"
        case 11: return "阴影"
        case 0: return "未知"
        default: return "其他光源"
        }
    }

    private func sceneName(_ value: Int) -> String {
        switch value {
        case 0: return "标准"
        case 1: return "风景"
        case 2: return "人像"
        case 3: return "夜景"
        default: return "其他"
        }
    }

    private func renderingValue(_ value: Int) -> String {
        switch value {
        case 0: return "标准"
        case 1: return "柔和"
        case 2: return "强烈"
        default: return "其他"
        }
    }

    private func meteringMode(_ value: Int) -> String {
        switch value {
        case 1: return "平均测光"
        case 2: return "中央重点"
        case 3: return "点测光"
        case 4: return "多点测光"
        case 5: return "矩阵测光"
        case 6: return "局部测光"
        case 0: return "未指定"
        default: return "其他"
        }
    }

    // MARK: - Loading

    private func load() {
        fileName = PHAssetResource.assetResources(for: asset).first?.originalFilename ?? ""

        if let location = asset.location {
            region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
            )
            pins = [MapPoint(coordinate: location.coordinate)]
            reverseGeocode(location)
        }

        guard asset.mediaType == .image else {
            isLoading = false
            return
        }

        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false

        PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
            DispatchQueue.main.async {
                isLoading = false
                guard let data else { return }
                fileSizeText = ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
                guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                      let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else { return }
                properties = props
                elevationText = elevation(from: props)
                if pins.isEmpty, let coordinate = coordinate(from: props) {
                    let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                    region = MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
                    )
                    pins = [MapPoint(coordinate: coordinate)]
                    reverseGeocode(location)
                }
            }
        }
    }

    private func coordinate(from props: [String: Any]) -> CLLocationCoordinate2D? {
        guard let gps = props[kCGImagePropertyGPSDictionary as String] as? [String: Any],
              let latitude = numberValue(gps[kCGImagePropertyGPSLatitude as String]),
              let longitude = numberValue(gps[kCGImagePropertyGPSLongitude as String]) else {
            return nil
        }
        let latitudeRef = stringValue(gps[kCGImagePropertyGPSLatitudeRef as String]).uppercased()
        let longitudeRef = stringValue(gps[kCGImagePropertyGPSLongitudeRef as String]).uppercased()
        let signedLatitude = latitudeRef == "S" ? -abs(latitude) : abs(latitude)
        let signedLongitude = longitudeRef == "W" ? -abs(longitude) : abs(longitude)
        return CLLocationCoordinate2D(latitude: signedLatitude, longitude: signedLongitude)
    }

    private func elevation(from props: [String: Any]) -> String {
        guard let gps = props[kCGImagePropertyGPSDictionary as String] as? [String: Any],
              let altitude = numberValue(gps[kCGImagePropertyGPSAltitude as String]) else {
            return ""
        }
        let ref = Int(numberValue(gps[kCGImagePropertyGPSAltitudeRef as String]) ?? 0)
        let meters = ref == 1 ? -altitude : altitude
        return "海拔 \(Int(meters.rounded())) m"
    }

    private func reverseGeocode(_ location: CLLocation) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, _ in
            guard let placemark = placemarks?.first else { return }
            let name = placemark.name ?? placemark.subLocality ?? placemark.locality ?? ""
            let area = [placemark.locality, placemark.subLocality]
                .compactMap { $0 }
                .filter { !$0.isEmpty && $0 != name }
                .joined(separator: " ")
            DispatchQueue.main.async {
                placeName = name
                areaName = area
            }
        }
    }
}
