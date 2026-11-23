import SwiftUI
import UIKit

struct SplashView: View {
    var body: some View {
        VStack(spacing: 18) {
            AppMark(size: 72)
            Text("SwipeClean")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Color.white.opacity(0.5))
                .padding(.top, 6)
        }
    }
}

struct AppMark: View {
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(LinearGradient(colors: [Theme.accent, Color(red: 0.93, green: 0.28, blue: 0.60)],
                                     startPoint: .topLeading,
                                     endPoint: .bottomTrailing))
            Image(systemName: "arrow.up")
                .font(.system(size: size * 0.42, weight: .heavy))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: Theme.accent.opacity(0.35), radius: size * 0.2, x: 0, y: size * 0.1)
    }
}

struct PermissionView: View {
    let onRequest: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            AppMark(size: 78)

            Text("让相册轻一点")
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.top, 22)

            Text("照片和视频分成两套卡片，上滑加入删除备选，每 30 项确认一次。\n需要相册权限才能开始，所有内容只在本机处理。")
                .font(.system(size: 14))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 12)
                .padding(.horizontal, 32)

            Button(action: onRequest) {
                Text("允许访问相册")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.accent))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 26)
            .padding(.top, 34)

            Text("SwipeClean 不会上传、备份或分析你的照片")
                .font(.system(size: 11))
                .foregroundColor(Theme.textTertiary)
                .padding(.top, 14)

            Spacer(minLength: 0)
        }
    }
}

struct DeniedView: View {
    let onOpenSettings: () -> Void
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            Image(systemName: "lock.slash")
                .font(.system(size: 46, weight: .light))
                .foregroundColor(Theme.textSecondary)

            Text("需要相册权限")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("请到「设置 → SwipeClean → 照片」中选择「完全访问」，然后回到这里。")
                .font(.system(size: 14))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 34)

            Button(action: onOpenSettings) {
                Text("前往设置")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.accent))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 26)
            .padding(.top, 10)

            Button(action: onRetry) {
                Text("重新检查")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
    }
}
