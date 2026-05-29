import SwiftUI

struct SidebarPaneSurface: Shape {
    var sidebarWidth: CGFloat
    var radius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(sidebarWidth, radius) }
        set {
            sidebarWidth = newValue.first
            radius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let x = rect.minX + sidebarWidth
        let radius = clampedRadius(radius, in: rect, boundaryX: x)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: x + radius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: x, y: rect.minY + radius),
            control: CGPoint(x: x, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: x, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: x + radius, y: rect.maxY),
            control: CGPoint(x: x, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }

}

struct DetailPaneSurface: Shape {
    var sidebarWidth: CGFloat
    var radius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(sidebarWidth, radius) }
        set {
            sidebarWidth = newValue.first
            radius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let x = rect.minX + sidebarWidth
        let radius = clampedRadius(radius, in: rect, boundaryX: x)

        var path = Path()
        path.move(to: CGPoint(x: x + radius, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: x + radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: x, y: rect.maxY - radius),
            control: CGPoint(x: x, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: x, y: rect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: x + radius, y: rect.minY),
            control: CGPoint(x: x, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }

}

struct SidebarRightBorder: Shape {
    var sidebarWidth: CGFloat
    var radius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(sidebarWidth, radius) }
        set {
            sidebarWidth = newValue.first
            radius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let x = rect.minX + sidebarWidth
        let radius = clampedRadius(radius, in: rect, boundaryX: x)

        var path = Path()
        path.move(to: CGPoint(x: x + radius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: x, y: rect.minY + radius),
            control: CGPoint(x: x, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: x, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: x + radius, y: rect.maxY),
            control: CGPoint(x: x, y: rect.maxY)
        )
        return path
    }

}

private func clampedRadius(_ radius: CGFloat, in rect: CGRect, boundaryX x: CGFloat) -> CGFloat {
    max(0, min(radius, rect.maxX - x, rect.height / 2))
}
