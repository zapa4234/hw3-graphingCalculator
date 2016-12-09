
import UIKit

class GraphingViewController: UIViewController, GraphingViewDataSource, UIPopoverPresentationControllerDelegate {
    fileprivate struct Constants {
        static let ScaleAndOrigin = "scaleAndOrigin"
    }
    
    @IBOutlet weak var graphingView: GraphingView! {
        didSet {
            graphingView.dataSource = self
            if let scaleAndOrigin = userDefaults.object(forKey: Constants.ScaleAndOrigin) as? [String: String] {
                graphingView.scaleAndOrigin = scaleAndOrigin
            }
        }
    }
    
    var program: AnyObject?
    var graphLabel: String? {
        didSet {
            title = graphLabel
        }
    }
    fileprivate let userDefaults = UserDefaults.standard
    
    func graphPlot(_ sender: GraphingView) -> [(x: Double, y: Double)]? {
        let minXDegree = Double(sender.minX) * (180 / M_PI)
        let maxXDegree = Double(sender.maxX) * (180 / M_PI)
        
        var plots = [(x: Double, y: Double)]()
        let brain = CalculatorBrain()
        
        if let program = program {
            brain.program = program
            
            // Performance fix to remove sluggish behavior (specially when screen is zoomed out):
            // a. the difference between minXDegree and maxXDegree will be high when zoomed out
            // b. the screen width has a fixed number of pixels, so we need to iterate only
            //    for the number of available pixels
            // c. loopIncrementSize ensures that the count of var plots will always be fixed to
            //    the number of available pixels for screen width
            let loopIncrementSize = (maxXDegree - minXDegree) / sender.availablePixelsInXAxis
            
//            for var i = 0; i < 10; i += 2 {
//                print(i)
//            }
            
//            for i in 0.stride(to: 10, by: 2) {
//                print(i)
//            }
            
//            for (var i = minXDegree; i <= maxXDegree; i = i + loopIncrementSize)

            for i in Swift.stride(from: Int(minXDegree), to: Int(maxXDegree), by: Int(loopIncrementSize))
                {
                let radian = Double(i) * (M_PI / 180)
                brain.variableValues["M"] = radian
                let evaluationResult = brain.evaluateAndReportErrors()
                switch evaluationResult {
                case let .success(y):
                    if y.isNormal || y.isZero {
                        plots.append((x: radian, y: y))
                    }
                default: break
                }
            }
        }
        
        return plots
    }
    
    @IBAction func zoomGraph(_ gesture: UIPinchGestureRecognizer) {
        if gesture.state == .changed {
            graphingView.scale *= gesture.scale
            
            // save the scale
            saveScaleAndOrigin()
            gesture.scale = 1
        }
    }
    
    @IBAction func moveGraph(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .ended: fallthrough
        case .changed:
            let translation = gesture.translation(in: graphingView)

            if graphingView.graphOrigin == nil {
                graphingView.graphOrigin = CGPoint(
                    x: graphingView.center.x + translation.x,
                    y: graphingView.center.y + translation.y)
            } else {
                graphingView.graphOrigin = CGPoint(
                    x: graphingView.graphOrigin!.x + translation.x,
                    y: graphingView.graphOrigin!.y + translation.y)
            }
            
            // save the graphOrigin
            saveScaleAndOrigin()
            
            // set back to zero, otherwise will be cumulative
            gesture.setTranslation(CGPoint.zero, in: graphingView)
        default: break
        }
    }
    
    @IBAction func moveOrigin(_ gesture: UITapGestureRecognizer) {
        switch gesture.state {
        case .ended:
            graphingView.graphOrigin = gesture.location(in: view)
            
            // save the graphOrigin
            saveScaleAndOrigin()
        default: break
        }
    }
    
    fileprivate func saveScaleAndOrigin() {
        userDefaults.set(graphingView.scaleAndOrigin, forKey: Constants.ScaleAndOrigin)
        userDefaults.synchronize()
    }
    
    // Detect device rotation and adjust origin to center instead of upper-left:
    // if graph origin is far off center, then rotation change might move it off-screen so
    // calcualtion also makes a subtle adjustment based on the ratio of the height and with change
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        
        var xDistanceFromCenter: CGFloat = 0
        var yDistanceFromCenter: CGFloat = 0
        if let graphOrigin = graphingView.graphOrigin {
            xDistanceFromCenter = graphingView.center.x - graphOrigin.x
            yDistanceFromCenter = graphingView.center.y - graphOrigin.y
        }
        
        let widthBeforeRotation = graphingView.bounds.width
        let heightBeforeRotation = graphingView.bounds.height
        
        coordinator.animate(alongsideTransition: nil) { context in
            
            let widthAfterRotation = self.graphingView.bounds.width
            let heightAfterRotation = self.graphingView.bounds.height
            
            let widthChangeRatio = widthAfterRotation / widthBeforeRotation
            let heightChangeRatio = heightAfterRotation / heightBeforeRotation

            self.graphingView.graphOrigin = CGPoint(
                x: self.graphingView.center.x - (xDistanceFromCenter * widthChangeRatio),
                y: self.graphingView.center.y - (yDistanceFromCenter * heightChangeRatio)
            )
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let identifier = segue.identifier {
            switch identifier {
            case "Show Stats":
                if let svc = segue.destination as? GraphStatisticsViewController {
                    if let ppc = svc.popoverPresentationController {
                        ppc.delegate = self
                    }
                    svc.stats  = "min-X: \(graphingView.minX)\n"
                    svc.stats += "max-X: \(graphingView.maxX)\n"
                    svc.stats += "min-Y: \(graphingView.minY)\n"
                    svc.stats += "max-Y: \(graphingView.maxY)"
                }
            default: break
            }
        }
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.none
    }
    
}
