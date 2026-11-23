import SwiftUI
import Photos
import ImageIO
import CoreLocation
import MapKit
import UIKit

/// The "详情" sheet behind the ⓘ button: date, dimensions, file info, camera
/// settings and a live MapKit snippet for the capture location.
struct AssetDetailSheet: View {
    let asset: PHAsset
    @Environment(\.dismiss) private var dismiss

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

    private struct MapPoint: Identifiable {
        let id = UUID()
        let coordinate: CLLocationCoordinate2D
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                header

                card {
                    row("拍摄时间", dateText)
                    divider
                    row("类型", typeText)
                    divider
                    row("分辨率", "\(asset.pixelWidth) × \(asset.pixelHeight)")
                    if asset.mediaType == .video {
                        divider
                        row("时长", durationText)
                    }
                    if !fileName.isEmpty {
                        divider
                        row("文件名", fileName)
                    }
                    if !fileSizeText.isEmpty {
                        divider
                        row("文件大小", fileSizeText)
                    }
                }

                if asset.mediaType == .image, !cameraRows.isEmpty {
                    sectionTitle("拍摄参数")
                    card {
                        ForEach(Array(cameraRows.enumerated()), id: \.offset) { index, item in
                            if index > 0 { divider }
                            row(item.0, item.1)
                        }
                    }
                }

                if !pins.isEmpty {
                    sectionTitle("拍摄位置")
                    locationCard
                }

                if isLoading {
                    HStack(spacing: 8) {
                        ProgressView().tint(.white.opacity(0.6))
                        Text("正在读取元数据…")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textTertiary)
                    }
                    .padding(.top, 4)
                }

                Text("照片本身不会显示这些信息，只有在这里查看")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Theme.background.ignoresSafeArea())
        .presentationDetents([.large])
        .onAppear(perform: load)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(asset.mediaType == .video ? "视频详情" : "照片详情")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Spacer()
            CircleIconButton(icon: "xmark") {
                dismiss()
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 2)
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
                .frame(height: 156)

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
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

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
            .padding(.horizontal, 4)
            .padding(.top, 12)
            .padding(.bottom, 14)

            if !coordinateText.isEmpty {
                Rectangle()
                    .fill(Theme.hairline)
                    .frame(height: 1)
                row("坐标", coordinateText)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
    }

    private var coordinateText: String {
        guard let location = asset.location else { return "" }
        return String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude)
    }

    // MARK: - Cards

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(.horizontal, 16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: 1)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(Theme.textSecondary)
            .padding(.leading, 4)
            .padding(.top, 4)
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(Theme.textSecondary)
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Formatting

    private var dateText: String {
        guard let date = asset.creationDate else { return "未知" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 EEEE HH:mm"
        return formatter.string(from: date)
    }

    private var typeText: String {
        asset.mediaType == .video ? "视频" : "照片"
    }

    private var durationText: String {
        let total = Int(asset.duration.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private var cameraRows: [(String, String)] {
        guard !properties.isEmpty else { return [] }
        let exif = (properties[kCGImagePropertyExifDictionary as String] as? [String: Any]) ?? [:]
        let tiff = (properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any]) ?? [:]
        var rows: [(String, String)] = []

        let make = tiff[kCGImagePropertyTIFFMake as String] as? String
        let model = tiff[kCGImagePropertyTIFFModel as String] as? String
        if let model {
            let device: String
            if let make, !model.hasPrefix(make) {
                device = "\(make) \(model)"
            } else {
                device = model
            }
            rows.append(("设备", device))
        }

        if let fNumber = exif[kCGImagePropertyExifFNumber as String] as? Double {
            rows.append(("光圈", String(format: "f/%.1f", fNumber)))
        }
        if let exposure = exif[kCGImagePropertyExifExposureTime as String] as? Double, exposure > 0 {
            if exposure < 1 {
                rows.append(("快门", "1/\(Int((1 / exposure).rounded())) s"))
            } else {
                rows.append(("快门", String(format: "%.1f s", exposure)))
            }
        }
        if let isoValues = exif[kCGImagePropertyExifISOSpeedRatings as String] as? [Int], let iso = isoValues.first {
            rows.append(("ISO", "\(iso)"))
        }
        if let focal = exif[kCGImagePropertyExifFocalLength as String] as? Double {
            rows.append(("焦距", String(format: "%.0f mm", focal)))
        }
        return rows
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
            }
        }
    }

    private func elevation(from props: [String: Any]) -> String {
        guard let gps = props[kCGImagePropertyGPSDictionary as String] as? [String: Any],
              let altitude = gps[kCGImagePropertyGPSAltitude as String] as? Double else {
            return ""
        }
        let ref = gps[kCGImagePropertyGPSAltitudeRef as String] as? Int ?? 0
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
