//
//  ViewController.swift
//  stay_away_app
//
//  Created by Ali Momennasab on 3/20/21.
//


import UIKit
import CoreBluetooth
import AudioToolbox
import AVFoundation

struct DetectedDevice {
    var name : String
    var rssi : Double
    var distance : Double
    var lastSeen : Date = Date()
}

class ViewController: UIViewController {
    var centralManager: CBCentralManager!
    var currentScannedPeripheral: CBPeripheral!
    //var currentBackgroundColor: UIColor?
    var timer: Timer?
    weak var progressTimer: Timer? //
    var peripheralRSSIList: [UUID: Int] = [:]
    var detectedDevices: [UUID: DetectedDevice] = [:]
    var isScanning: Bool = false
    var progress: Float = 0.0
    var closestDistance: Double = 100000000.0
    var updatedPeripheralName: String?
    @IBOutlet weak var startScanButton: UIButton!
    @IBOutlet weak var displaySafeLabel: UILabel!
    @IBOutlet weak var displayUnsafeLabel: UILabel!
    @IBOutlet weak var closestDeviceIsLabel: UILabel!
    @IBOutlet weak var closestDistanceLabel: UILabel!
    @IBOutlet weak var currentlyScanningLabel: UILabel!
    @IBOutlet weak var instructionsLabel1: UITextView!
    @IBOutlet weak var ProgressView: UIProgressView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let defaultBackground = CAGradientLayer()
        defaultBackground.frame = view.bounds
        defaultBackground.colors = [
            UIColor.systemTeal.cgColor,
            UIColor.systemBlue.cgColor
        ]
        
        let safeBackground = CAGradientLayer()
        safeBackground.frame = view.bounds
        safeBackground.colors = [
            UIColor.systemTeal.cgColor,
            UIColor.systemGreen.cgColor
        ]
        
        let unsafeBackground = CAGradientLayer()
        unsafeBackground.frame = view.bounds
        unsafeBackground.colors = [
            UIColor.systemOrange.cgColor,
            UIColor.systemRed.cgColor
        ]
        
        view.layer.insertSublayer(defaultBackground, at: 0)

        //view.backgroundColor = .systemTeal
        centralManager = CBCentralManager(delegate:self, queue: nil)
        
        
        displaySafeLabel.isHidden = true
        displaySafeLabel.numberOfLines = 0

        
        displayUnsafeLabel.isHidden = true
        displayUnsafeLabel.numberOfLines = 0

        
        closestDeviceIsLabel.isHidden = true
        closestDeviceIsLabel.numberOfLines = 0

        
        closestDistanceLabel.isHidden = true
        closestDistanceLabel.numberOfLines = 0

        
        currentlyScanningLabel.isHidden = true
        currentlyScanningLabel.numberOfLines = 0
        
        startScanButton.isEnabled = false
        
        startScanButton.layer.cornerRadius = 30
        startScanButton.clipsToBounds = true
        
        ProgressView.progress = 0.0
        ProgressView.isHidden = true
    }
    
    @IBAction func handleScanButtonPress(_ sender: UIButton) {
        self.progress = 0.0
        
        isScanning = !isScanning
        if isScanning {
            sender.setTitle("STOP SCANNING", for: .normal)
            currentlyScanningLabel.isHidden = false
            instructionsLabel1.isHidden = true
            
            ProgressView.isHidden = false
            ProgressView.progress = progress
            progressTimer = Timer.scheduledTimer(withTimeInterval:
                    0.01, repeats: true, block: { (progressTimer) in
                        self.progress += (1/150)
                        self.ProgressView.progress = self.progress
                        
                        if self.ProgressView.progress == 100.0{
                            self.ProgressView.progress = 0.0
                        }
            })
            
            timer = Timer.scheduledTimer(timeInterval: 1.5, target: self, selector: #selector(scanForPeripherals), userInfo: nil, repeats: true)
            
        } else {
            sender.setTitle("START SCANNING", for: .normal)
            //view.backgroundColor = currentBackgroundColor
            //startScanButton.setTitleColor(.systemTeal, for: .normal)
            UIView.animate(withDuration: 0.2, animations: {
                self.startScanButton.setTitleColor(.systemTeal, for: .normal)
            }, completion: nil)
            UIView.animate(withDuration: 0.2, animations: {
                self.view.backgroundColor = .systemTeal
            }, completion: nil)
            timer?.invalidate()
            progressTimer?.invalidate()
            centralManager.stopScan()
            detectedDevices.removeAll()
            displayUnsafeLabel.isHidden = true
            displaySafeLabel.isHidden = true
            closestDeviceIsLabel.isHidden = true
            closestDistanceLabel.isHidden = true
            currentlyScanningLabel.isHidden = true
            updatedPeripheralName = nil
            instructionsLabel1.isHidden = false
            ProgressView.isHidden = true
        }
        
    }
    
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected!")
    }
}

extension UIDevice {
    static func vibrate() {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
}

extension ViewController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state{
        case .unknown:
            print("central.state is .unknown")
        case .resetting:
            print("central.state is .resetting")
        case .unsupported:
            print("central.state is .unsupported")
        case .unauthorized:
            print("central.state is .unauthorized")
        case .poweredOff:
            print("central.state is .poweredOff")
        case .poweredOn:
            print("central.state is .poweredOn")
            startScanButton.isEnabled = true
        @unknown default:
            print("")
        }
    }
    
    //update peripheral name when found
    func peripheralDidUpdateName(_ peripheral: CBPeripheral){
        updatedPeripheralName = peripheral.name
        print("updatedPeripheralName: \(String(describing: updatedPeripheralName))")
    }
    
    
    //main function
    @objc func scanForPeripherals() {
        //start scan
        centralManager.scanForPeripherals(withServices: nil)
    }
    
    //when scan detects peripheral
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        ProgressView.isHidden = true
        currentlyScanningLabel.isHidden = true
        currentScannedPeripheral = peripheral
        print(currentScannedPeripheral!)
        //connect to peripheral to receive data
        centralManager.connect(peripheral)
        //centralManager.stopScan()
        
        
        var safe = true
        closestDistance = 100000000.0
        var closestDevice: String?
        let currentTxPower = (advertisementData[CBAdvertisementDataTxPowerLevelKey] as? Double ?? 59.0) * -1.0
        let rssiValue = Double(truncating: RSSI)
        
        //add detected device into list of detected devices
        var detectedDevice = DetectedDevice.init(
            name: peripheral.name ?? "No Name",
            rssi: rssiValue,
            distance: calculateAvgDistance(rssi: rssiValue, txPower: currentTxPower)
        )
        
        print("UUID:", peripheral.identifier, "Device:", detectedDevice, "Distance", detectedDevice.distance)
        
        detectedDevices[peripheral.identifier] = detectedDevice
        
        if (detectedDevice.name != updatedPeripheralName) && (updatedPeripheralName != nil){
                    detectedDevice.name = updatedPeripheralName ?? detectedDevice.name
                }
        
        for (_, DetectedDevice) in detectedDevices{
            if DetectedDevice.distance < 6{
                safe = false
            }
            if DetectedDevice.distance < closestDistance{
                closestDistance = DetectedDevice.distance
                closestDevice = DetectedDevice.name
            }
        }
        
        centralManager.stopScan()
        
        print("Closest device (\(String(describing: closestDevice))) is approximately \(closestDistance) feet away.")
        closestDeviceIsLabel.isHidden = false
        closestDistanceLabel.isHidden = false
        
        if (closestDistance == 100000000.0) || (detectedDevices.isEmpty){
            view.backgroundColor = currentBackgroundColor
            UIView.animate(withDuration: 0.2, animations: {
                //self.view.backgroundColor = .systemGreen
            }, completion: nil)
            
            let colorsAnimation = CABasicAnimation(keyPath: #keyPath(CAGradientLayer.colors))
            colorsAnimation.fromValue = .colors
            colorsAnimation.toValue = newColors
            colorsAnimation.duration = 5.0
            colorsAnimation.delegate = self
            colorsAnimation.fillMode = .forwards
            colorsAnimation.isRemovedOnCompletion = false
            gradientLayer.add(colorsAnimation, forKey: "colors")
            
            currentBackgroundColor = view.backgroundColor
            startScanButton.setTitleColor(.systemGreen, for: .normal)
            displayUnsafeLabel.isHidden = true
            displaySafeLabel.isHidden = false
            closestDeviceIsLabel.text = "There are no nearby devices."
            closestDeviceIsLabel.textAlignment = .center
            closestDistanceLabel.text = ""
        } else {
            if safe {
                view.backgroundColor = currentBackgroundColor
                UIView.animate(withDuration: 0.2, animations: {
                    self.view.backgroundColor = .systemGreen
                }, completion: nil)
                //view.backgroundColor = .systemGreen
                currentBackgroundColor = view.backgroundColor
                startScanButton.setTitleColor(.systemGreen, for: .normal)
                print("You are safe!")
                displayUnsafeLabel.isHidden = true
                displaySafeLabel.isHidden = false
                if closestDevice != ""{
                    if closestDistance <= 30 {
                    closestDeviceIsLabel.text = "Closest device (\(String(closestDevice ?? ""))) is"
                    closestDistanceLabel.text = "approximately \(round(closestDistance*10) / 10.0) feet away."
                    } else {
                    closestDeviceIsLabel.text = "There are no nearby devices."
                    closestDeviceIsLabel.textAlignment = .center
                    closestDistanceLabel.text = ""
                    }
                } else {
                    closestDeviceIsLabel.text = "There are no nearby devices."
                    closestDeviceIsLabel.textAlignment = .center
                    closestDistanceLabel.text = ""
                }
                
            } else {
                view.backgroundColor = currentBackgroundColor
                UIView.animate(withDuration: 0.2, animations: {
                    self.view.backgroundColor = .systemRed
                }, completion: nil)
                currentBackgroundColor = view.backgroundColor
                //view.backgroundColor = .systemRed
                startScanButton.setTitleColor(.systemRed, for: .normal)
                print("You are not safe!")
                displaySafeLabel.isHidden = true
                displayUnsafeLabel.isHidden = false
                UIDevice.vibrate()
                closestDeviceIsLabel.text = "Closest device (\(String(closestDevice ?? ""))) is"
                closestDeviceIsLabel.textAlignment = .center
                closestDistanceLabel.text = "approximately \(round(closestDistance*10) / 10.0) feet away."
                closestDistanceLabel.textAlignment = .center
            }
        }
        centralManager.cancelPeripheralConnection(peripheral)
        closestDistance = 100000000.0
        detectedDevices.removeAll()
    }
}

func calculateNewDistance1(rssi: Double, txPower: Double) -> Double{
    if (rssi == 0) {
        return -1.0 // if we cannot determine accuracy, return -1.
    }
    
    let ratio = (rssi * 1.0) / txPower
    if (ratio < 1.0) {
        return pow(ratio,10)
    }
    else {
        let accuracy =  (0.89976) * pow(ratio,7.7095) + 0.111
        return accuracy
    }
}

    func calculateNewDistance2(rssi:Double) -> Double {
    let txPower = -61.0 //usually works with 61
    print("Rssi: \(rssi)")
    print("txPower: \(txPower)")
    let ratio_db = txPower - rssi;
    print("RatioDb: \(ratio_db)")
    let ratio_linear = pow(10, ratio_db / 10);
    return sqrt(ratio_linear);
}

func calculateAvgDistance (rssi: Double, txPower: Double) -> Double {
    /* let d1 = calculateNewDistance1(rssi: rssi, txPower: txPower) * 3.281
    print("d1: \(d1)") */
    let d2 = calculateNewDistance2(rssi: rssi) * 3.281
    print("d2: \(d2)")
   /* let sum = d1 + d2
    return sum/2 */
    return d2
}
