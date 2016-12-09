
import UIKit

protocol GraphingViewDataSource: class {
    func graphPlot(_ sender: GraphingView) -> [(x: Double, y: Double)]?
}

@IBDesignable
class GraphingView: UIView {
    weak var dataSource: GraphingViewDataSource?
    
    @IBInspectable var axesColor: UIColor = UIColor.blue { didSet { setNeedsDisplay() } }
    @IBInspectable var plotColor: UIColor = UIColor.red  { didSet { setNeedsDisplay() } }
    @IBInspectable var scale: CGFloat = 1.0                     { didSet { setNeedsDisplay() } }
    @IBInspectable var graphOrigin: CGPoint?                    { didSet { setNeedsDisplay() } }
    
    let pointsPerUnit: CGFloat = 50.0
    
    var graphCenter: CGPoint {
        if graphOrigin != nil {
            return convert(graphOrigin!, from: superview)
        }
        return convert(center, from: superview)
    }
    
    typealias PropertyList = [String: String]
    var scaleAndOrigin: PropertyList {
        get {
            let origin = (graphOrigin != nil) ? graphOrigin! : center
            return [
                "scale": "\(scale)",
                "graphOriginX": "\(origin.x)",
                "graphOriginY": "\(origin.y)"
            ]
        }
        set {
            if let scale = newValue["scale"], let graphOriginX = newValue["graphOriginX"], let graphOriginY = newValue["graphOriginY"] {
                if let scale = NumberFormatter().number(from: scale) {
                    self.scale = CGFloat(scale)
                }
                if let graphOriginX = NumberFormatter().number(from: graphOriginX), let graphOriginY = NumberFormatter().number(from: graphOriginY) {
                    self.graphOrigin = CGPoint(x: CGFloat(graphOriginX), y: CGFloat(graphOriginY))
                }                
            }
        }
    }
    
    var minX: CGFloat {
        let minXBound = -(bounds.width - (bounds.width - graphCenter.x))
        return minXBound / (pointsPerUnit * scale)
    }
    var minY: CGFloat {
        let minYBound = -(bounds.height - graphCenter.y)
        return minYBound / (pointsPerUnit * scale)
    }
    var maxX: CGFloat {
        let maxXBound = bounds.width - graphCenter.x
        return maxXBound / (pointsPerUnit * scale)
    }
    var maxY: CGFloat {
        let maxYBound = bounds.height - (bounds.height - graphCenter.y)
        return maxYBound / (pointsPerUnit * scale)
    }
    var availablePixelsInXAxis: Double {
        return Double(bounds.width * contentScaleFactor)
    }

    fileprivate func translatePlot(_ plot: (x: Double, y: Double)) -> CGPoint {
        let translatedX = CGFloat(plot.x) * pointsPerUnit * scale + graphCenter.x
        let translatedY = CGFloat(-plot.y) * pointsPerUnit * scale + graphCenter.y
        return CGPoint(x: translatedX, y: translatedY)
    }
    
    override func draw(_ rect: CGRect) {
        let axes = AxesDrawer(color: axesColor, contentScaleFactor: contentScaleFactor)
        axes.drawAxesInRect(bounds, origin: graphCenter, pointsPerUnit: pointsPerUnit*scale)
        
        let bezierPath = UIBezierPath()
        
        if var plots = dataSource?.graphPlot(self) , plots.first != nil {
            bezierPath.move(to: translatePlot((x: plots.first!.x, y: plots.first!.y)))
            plots.removeFirst()
            for plot in plots {
                bezierPath.addLine(to: translatePlot((x: plot.x, y: plot.y)))
            }
        }
        
        plotColor.set()
        bezierPath.stroke()
        
    }

}
