//
//  GTPlaceSpecialOrderViewController.swift
//  BaoGeiWo
//
//  Created by wb on 2018/10/16.
//  Copyright © 2018 qyqs. All rights reserved.
//

import UIKit

class GTPlaceSpecialOrderViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, WQPickerViewDelegate, GTPlaceOrderCellDelegate, GTPlaceOrderNotesCellDelegate, AMapSearchDelegate {
    func selectEnterpriseCounter(counter: BGWAirportCounterModel) {
        
    }
    
    
    var search = AMapSearchAPI()!
    
    var tableView: UITableView!
    
    let itemTexts = [["寄件城市", "寄件地址", "寄件时间", "航班号    "],
                     ["收件城市", "收件类型", "收  件  人", "姓        名", "联系方式", "收件地址", "航班号    ", "门牌号    ", "预计时间", "预计里程"],
                     ["手机号码", "客户姓名", "证件编号"],
                     ["行李数量"],
                     ["备注"]]
    let placeholders = [["请选择寄件城市", "请选择寄件地址", "请选择寄件时间", "请输入航班号"],
                        ["请选择收件城市", "请选择收件类型", "请选择收件人类型", "请输入收件人姓名", "请输入收件人联系方式", "请输入收件地址", "请输入航班号(选填)", "请输入门牌号(选填)", "预计时间", "预计里程"],
                        ["请输入电话", "请输入姓名", "请输入证件号"]]
    let tfsIsEditing = [[false, false, false, true],
                        [false, false, false, true, true, false, true, true, false, false],
                        [true, true, true]]
    var itemDetailTexts = [[String]]()
    var placeOrderModel = GTPlaceOrderModel()
    var receive_type = ReceiveType.none
    var recipient_type = RecipientType.oneSelf
    var send_hour = -4
    
    var priceView: GTPlaceOrderPriceView!
    var priceDetailView: GTPlaceOrderPriceDetailView!
    
    // 收取行李 19.1.2
    var baggages = [OrderBaggageModel]()
    var currentBaggageRow = 0
    
    func updateItemDetailTexts() {
        self.updateItemDetailTexts(reload: true)
    }
    func updateItemDetailTexts(reload: Bool) {
        itemDetailTexts.removeAll()
        itemDetailTexts.append([placeOrderModel.sendCity, placeOrderModel.sendAddress, placeOrderModel.sendTime, placeOrderModel.sendFlightNumber])
        itemDetailTexts.append([placeOrderModel.receiveCity, placeOrderModel.receiveType, placeOrderModel.recipientType, placeOrderModel.receiverName, placeOrderModel.receiverPhone, placeOrderModel.receiveAddress, placeOrderModel.receiveFlightNumber, placeOrderModel.receiveHouseNumber, placeOrderModel.receiveTime, placeOrderModel.distance+"Km"])
        itemDetailTexts.append([placeOrderModel.cusPhone, placeOrderModel.cusName, placeOrderModel.cusIDNumber])
        
        if reload {
            self.updateBaggages()
            tableView.reloadData()
            self.setTotalPrice()
        }

    }
    
    func setTotalPrice() {
        let distance = Int(self.placeOrderModel.distance)!
        self.placeOrderModel.totalPrice = self.priceView.setSpecOrderPrice(distance, self.placeOrderModel.baggageNumber, self.placeOrderModel.safeTag)
        self.placeOrderModel.actualPrice = self.placeOrderModel.totalPrice
        self.priceDetailView.setPriceDetail(distance, self.placeOrderModel.baggageNumber, self.placeOrderModel.safeTag, 0)
    }
    
    func updateBaggages() {
        if baggages.count != placeOrderModel.baggageNumber {
            if baggages.count < placeOrderModel.baggageNumber {
                while baggages.count < placeOrderModel.baggageNumber {
                    baggages.append(OrderBaggageModel.init())
                }
            } else {
                while baggages.count > placeOrderModel.baggageNumber {
                    baggages.removeLast()
                }
            }
        }
    }
    
    
    func setReceiveTime() {
        let time = self.stringToTimeStamp(stringTime: self.placeOrderModel.sendTimeFormat) + self.placeOrderModel.duration
        self.timeStampToString(timeStamp: time.description)
    }
    
    func calculateDistanceAndTime() {
        
        let startDict: NSDictionary = try! JSONSerialization.jsonObject(with: placeOrderModel.srcCoordinate.data(using: String.Encoding.utf8)!, options: []) as! NSDictionary
        let destDict: NSDictionary = try! JSONSerialization.jsonObject(with: placeOrderModel.destCoordinate.data(using: String.Encoding.utf8)!, options: []) as! NSDictionary
        let startLat = Float(startDict.object(forKey: "lat") as! String)
        let startLng = Float(startDict.object(forKey: "lng") as! String)
        
        let destLat = Float(destDict.object(forKey: "lat") as! String)
        let destLng = Float(destDict.object(forKey: "lng") as! String)
        
        let startCoor        = CLLocationCoordinate2DMake(CLLocationDegrees(startLat!), CLLocationDegrees(startLng!))
        let destinationCoor  = CLLocationCoordinate2DMake(CLLocationDegrees(destLat!), CLLocationDegrees(destLng!))
        
        let startCoordinate = AMapCoordinateConvert(startCoor, AMapCoordinateType.baidu);
        let destinationCoordinate = AMapCoordinateConvert(destinationCoor, AMapCoordinateType.baidu);

        let request = AMapDrivingRouteSearchRequest()
        request.origin = AMapGeoPoint.location(withLatitude: CGFloat(startCoordinate.latitude), longitude: CGFloat(startCoordinate.longitude))
        request.destination = AMapGeoPoint.location(withLatitude: CGFloat(destinationCoordinate.latitude), longitude: CGFloat(destinationCoordinate.longitude))
        request.requireExtension = true
        request.strategy = 4;
        self.search.aMapDrivingRouteSearch(request)

    }
    
    
    //MARK: - TableView
    func numberOfSections(in tableView: UITableView) -> Int {
        return itemTexts.count+1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section<itemTexts.count ? itemTexts[section].count : placeOrderModel.baggageNumber;
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 3 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "GTPlaceOrderBaggageCell", for: indexPath) as! GTPlaceOrderBaggageCell
            cell.setCellContent(self.placeOrderModel.baggageNumber, self.placeOrderModel.safeTag)
            cell.numberChange = { (number) in
                self.placeOrderModel.baggageNumber = number
                self.updateBaggages()
                tableView.reloadData()
                self.setTotalPrice()
            }
            cell.safeTagChange = { (tag) in
                self.placeOrderModel.safeTag = tag
                self.placeOrderModel.safeCode = "000" + tag.description
                self.setTotalPrice()
            }
            return cell
            
        } else if indexPath.section == 4 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "GTPlaceOrderNotesCell", for: indexPath) as! GTPlaceOrderNotesCell
            cell.delagate = self
            cell.textView.text = self.placeOrderModel.notes
            return cell
            
        } else if indexPath.section == 5 { //收取行李
            let cell = tableView.dequeueReusableCell(withIdentifier: "OrderTaskDetailBaggageCell", for: indexPath) as! OrderTaskDetailBaggageCell
            cell.setBaggageInfo(baggages[indexPath.row], roleType: 0)
            cell.takePreviewBlock = {
                self.currentBaggageRow = indexPath.row
                self.takePreview()
            }
            cell.scanBlock = {
                self.currentBaggageRow = indexPath.row
                self.scan()
            }
            return cell
            
        } else {
            var cell: GTPlaceOrderCell
            if indexPath.row == 0 {
                cell = tableView.dequeueReusableCell(withIdentifier: "GTPlaceOrderSectionHeaderCell", for: indexPath) as! GTPlaceOrderSectionHeaderCell
            } else {
                cell = tableView.dequeueReusableCell(withIdentifier: "GTPlaceOrderCell", for: indexPath) as! GTPlaceOrderCell
            }
            cell.delegate = self
            
            cell.itemTextLabel.text = itemTexts[indexPath.section][indexPath.row]
            cell.itemTextField.placeholder = placeholders[indexPath.section][indexPath.row]
            cell.itemTextField.text = itemDetailTexts[indexPath.section][indexPath.row]
            cell.itemTextField.isEnabled = tfsIsEditing[indexPath.section][indexPath.row]
            cell.itemTextField.tag = indexPath.section*20+indexPath.row
            
            cell.itemText = itemTexts[indexPath.section][indexPath.row]
            
            return cell
        }
        
    }
    
    
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        if (indexPath.section, indexPath.row) == (0, 3) { //隐藏寄件航班号
            return 0
        }
        
        if (indexPath.section, indexPath.row) == (1, 2) { //收件人 (本人or他人)
            if receive_type == .airport { //收件方式是机场, 隐藏收件人选择
                return 0
            }
        }
        
        if (indexPath.section, indexPath.row) == (1, 3) || (indexPath.section, indexPath.row) == (1, 4) {
            if recipient_type == .oneSelf { //收件人是本人,隐藏收件人名字和联系方式
                return 0
            }
        }
        
        if (indexPath.section, indexPath.row) == (1, 6) { //航班号
            if receive_type != .airport { //收件方式不是机场,隐藏航班号
                return 0
            }
        }
        
        if (indexPath.section, indexPath.row) == (1, 7) { //门牌号
            if receive_type != .house { //收件方式不是住宅,隐藏门牌号
                return 0
            }
        }
        
        
        return UITableViewAutomaticDimension
    }
    
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == itemTexts.count-1 { //行李数量和保价
            return
        }
        
        switch (indexPath.section, indexPath.row) {
        //寄件
        case (0, 0): break
        case (0, 1): break
        case (0, 2):
            let pickerVC = WQPickerViewController()
            pickerVC.style = .date_send
            pickerVC.delegate = self
            pickerVC.modalPresentationStyle = .overFullScreen
            self.present(pickerVC, animated: false, completion: nil)
            break
        case (0, 3): break
        //收件
        case (1, 0):
            if self.placeOrderModel.sendTime == "" {
                LPPopup.popupCustomText("请选择寄件时间")
                return
            }
            let pickerVC = WQPickerViewController()
            pickerVC.style = .address
            pickerVC.delegate = self
            pickerVC.modalPresentationStyle = .overFullScreen
            self.present(pickerVC, animated: false, completion: nil)
            break
        case (1, 1):
            //收件类型
            let pickerVC = WQPickerViewController()
            pickerVC.style = .receive_type
            pickerVC.delegate = self
            pickerVC.modalPresentationStyle = .overFullScreen
            self.present(pickerVC, animated: false, completion: nil)
            break
            
        case (1, 2): //收件人类型
            let pickerVC = WQPickerViewController()
            pickerVC.style = .recipient_type
            pickerVC.delegate = self
            pickerVC.modalPresentationStyle = .overFullScreen
            self.present(pickerVC, animated: false, completion: nil)
            break
        case (1, 3): break //收件人姓名
        case (1, 4): break //收件人联系方式
        case (1, 5):
            //收件地址
            if self.placeOrderModel.destCityName == "" {
                LPPopup.popupCustomText("请选择收件城市")
                return
            }
            if receive_type == .none {
                LPPopup.popupCustomText("请选择收件类型")
                
            } else if receive_type == .airport {
                
                OrderRequest_swift.getCounterByProvinceId(self.placeOrderModel.destProvinceId, cityId: self.placeOrderModel.destCityId, success: { (counters) in
                    let pickerVC = WQPickerViewController()
                    pickerVC.style = .counter
                    pickerVC.airportCounters = (counters as! [BGWAirportCounterModel])
                    pickerVC.delegate = self
                    pickerVC.modalPresentationStyle = .overFullScreen
                    self.present(pickerVC, animated: false, completion: nil)
                }) { (error) in
                    //
                }
                

            } else {
                let vc = GTPlaceOrderAddressViewController.init(cityName: self.placeOrderModel.destCityName)
                vc.addressInfo = { (address, landmark, coordinate, district, township) in
                    self.placeOrderModel.receiveAddress = landmark
                    self.updateItemDetailTexts()
                    self.placeOrderModel.destAddressId = ""
                    self.placeOrderModel.destAddress = address
                    self.placeOrderModel.destLandmark = landmark
                    self.placeOrderModel.destCoordinate = coordinate
                    self.placeOrderModel.destDistrictName = district
                    self.placeOrderModel.destTownshipName = township
                    self.calculateDistanceAndTime()
                }
                self.navigationController?.pushViewController(vc, animated: true)
            }
            break
        case (1, 6): break //航班号
        case (1, 7): break //门牌号
        case (1, 8): break //预计时间
        case (1, 9): break //预计里程
            
        case (2, 0): break
        case (2, 1): break
        case (2, 2): break
            
        default: break
        }
        
    }
    
    // MARK: - EventResponse
    func takePreview() {
        let baggage = baggages[currentBaggageRow]
        let vc = OrderImagePreviewViewController.init(imageUrls:baggage.baggageImage.takeImageUrls)!
        vc.isTake = true
        vc.isPreview = false
        vc.uploadSuccess = { (imageUrls) in
            baggage.baggageImage.takeImageUrls = imageUrls
            DispatchQueue.main.async {
                self.tableView.reloadRows(at: [IndexPath.init(row: self.currentBaggageRow, section: 5)], with: .automatic)
            }
        }
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func scan() {
        let vc = ScanViewController.init(scanType: 2)!
        
        vc.scanSuccessBlock = { (result) in
            print("12")
            self.saveQRCode(qrCode: result as! String, success: {
                self.navigationController?.popViewController(animated: true)
            }, failure: {
                vc.startScan()
            })
            
        }
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func saveQRCode(qrCode: String, success: @escaping ()->Void, failure: @escaping ()->Void) {
        SVProgressHUD.show()
        
        OrderRequest_swift.queryQRCodeIsUseful(qrCode, success: { (object) in
            SVProgressHUD.dismiss()
            let baggage = self.baggages[self.currentBaggageRow]
            baggage.baggageQRCode = qrCode
            DispatchQueue.main.async {
                self.tableView.reloadRows(at: [IndexPath.init(row: self.currentBaggageRow, section: 5)], with: .automatic)
            }
            
            success()
            
        }) { (error) in
            SVProgressHUD.dismiss()
            failure()
        }
    }
    
    
    
    
    // MARK: - WQPickerViewDelegate
    func selectReceiveType(type: String) {
        if self.placeOrderModel.receiveType == type {
            return
        }
        self.setReceiveType(type)
        self.placeOrderModel.receiveType = type
        self.placeOrderModel.receiveAddress = "" //清空收件地址
        self.updateItemDetailTexts()
    }
    
    func selectRecipientType(type: String) {
        if self.placeOrderModel.recipientType == type {
            return
        }
        self.setRecipientType(type)
        self.placeOrderModel.recipientType = type
        self.updateItemDetailTexts()
    }
    
    
    func selectCounter(counter: BGWAirportCounterModel) {
        placeOrderModel.receiveAddress = counter.counterName + "-" + counter.counterRemark
        self.updateItemDetailTexts()
        placeOrderModel.destAddressId = counter.counterId
        placeOrderModel.destLandmark = counter.counterName + counter.counterRemark
        placeOrderModel.destAddress = placeOrderModel.destLandmark
        self.placeOrderModel.destCoordinate = counter.counterCoordinate
//        placeOrderModel.destCoordinate = try! String(data: JSONSerialization.data(withJSONObject: counter.counterCoordinate, options: []), encoding: String.Encoding.utf8)!
    }
    
    func selectDate(_ date: String, displayDate: String, hour: String, minute: String, style: PickerStyle) {
        let displayTime = displayDate + "  " + hour + ":" + minute
        let formatTime = date + " " + hour + ":" + minute + ":" + "00"
        if style == .date_send {
            placeOrderModel.sendTime = displayTime
            placeOrderModel.receiveTime = ""
            send_hour = Int(hour)!
            
            placeOrderModel.sendTimeFormat = formatTime
            if placeOrderModel.duration > 0 { //已选目的地
                self.setReceiveTime() //重新计算到达时间
            } else {
                placeOrderModel.receiveTimeFormat = ""
            }
        } else if style == .date_receive {
            placeOrderModel.receiveTime = displayTime
            
            placeOrderModel.receiveTimeFormat = formatTime
        }
        self.updateItemDetailTexts()
    }
    
    func selectAddress(_ province: String, _ provinceCode: String, _ city: String, _ cityCode: String) {
        if cityCode == placeOrderModel.destCityId {
            return
        }
        placeOrderModel.receiveCity = province + " " + city
        placeOrderModel.destProvinceName = province
        placeOrderModel.destProvinceId = provinceCode
        placeOrderModel.destCityName = city
        placeOrderModel.destCityId = cityCode
        // 清空收件地址
        placeOrderModel.receiveAddress = ""
        placeOrderModel.destAddressId = ""
        placeOrderModel.destLandmark = ""
        placeOrderModel.destAddress = ""
        placeOrderModel.destCoordinate = ""
        
        self.updateItemDetailTexts()
    }
    
    
    //MARK: - GTPlaceOrderCellDelegate
    func itemScanClick() {
        let vc = GTPlaceOrderScanPersonInfoViewController.init()
        vc.getPersonInfo = { (name, number) in
            self.placeOrderModel.cusName = name
            self.placeOrderModel.cusIDNumber = number
            self.placeOrderModel.sendName = name
            self.placeOrderModel.sendIdNumber = number
            if self.recipient_type != .others {
                self.placeOrderModel.receiverName = name
                self.placeOrderModel.receiverIdNumber = number
            }
            
            self.updateItemDetailTexts()
        }
        self.present(vc, animated: true, completion: nil)
    }
    
    func itemTextFieldEndEditing(_ textField: UITextField) {
        let text = textField.text ?? ""
        switch textField.tag {
        case 23:
            //收件人姓名
            self.placeOrderModel.receiverName = text
            break
        case 24:
            //收件人联系方式
            self.placeOrderModel.receiverPhone = text
            break
        case 26:
            //航班号
            self.placeOrderModel.receiveFlightNumber = text
            break
        case 27:
            //门牌号
            self.placeOrderModel.receiveHouseNumber = text;
            self.placeOrderModel.destAddress = self.placeOrderModel.destAddress + " " + text
            break
        case 40:
            //客户手机号
            self.placeOrderModel.cusPhone = text
            self.placeOrderModel.sendPhone = text
            if recipient_type != .others {
                self.placeOrderModel.receiverPhone = text
            }
            break
        case 41:
            //客户姓名
            self.placeOrderModel.cusName = text
            self.placeOrderModel.sendName = text
            if recipient_type != .others {
                self.placeOrderModel.receiverName = text
            }
            break
        case 42:
            //客户证件编号
            self.placeOrderModel.cusIDNumber = text
            self.placeOrderModel.sendIdNumber = text
            if recipient_type != .others {
                self.placeOrderModel.receiverIdNumber = text
            }
            break
        default:
            break
        }
        self.updateItemDetailTexts(reload: false)

    }
    
    //MARK: - GTPlaceOrderNotesCellDelegate
    func textViewEndEditing(_ textView: UITextView) {
        self.placeOrderModel.notes = textView.text
        self.updateItemDetailTexts()
    }
    
    //MARK: - AMAPDELEGATE
    func onRouteSearchDone(_ request: AMapRouteSearchBaseRequest!, response: AMapRouteSearchResponse!) {
        if response.count > 0 {
            //解析response获取路径信息
            print(response.route.paths.count)
            let mapPath = response.route.paths.first!
            let distance = Int(ceilf(Float(mapPath.distance)/1000.0))
            self.placeOrderModel.distance = distance.description
            self.placeOrderModel.duration = mapPath.duration+3600
            
            self.setReceiveTime()
            self.updateItemDetailTexts()
            
            print(mapPath.duration)
            print(mapPath.distance)
        }
    }
    
    func aMapSearchRequest(_ request: Any!, didFailWithError error: Error!) {
        print("Error:\(String(describing: error))")
    }
    
    
    func stringToTimeStamp(stringTime: String)->Int {
        
        let dfmatter = DateFormatter()
        dfmatter.dateFormat="yyyy-MM-dd HH:mm:ss"
        let date = dfmatter.date(from: stringTime)
        
        let dateStamp:TimeInterval = date!.timeIntervalSince1970
        
        let dateSt:Int = Int(dateStamp)
//        print(dateSt)
        return dateSt
        
    }
    
    func timeStampToString(timeStamp:String) {
        
        let string = NSString(string: timeStamp)
        let timeSta:TimeInterval = string.doubleValue
        let date = Date(timeIntervalSince1970: timeSta)
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "zh-Hans")
        dateFormatter.dateFormat="yyyy-MM-dd HH:mm:ss"
        
        self.placeOrderModel.receiveTimeFormat = dateFormatter.string(from: date)
        
        dateFormatter.dateFormat = "MM月d日 HH:mm"
        self.placeOrderModel.receiveTime = dateFormatter.string(from: date)

    }
    

    
    //MARK: - ViewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        placeOrderModel.channel = "app_sc"
        placeOrderModel.payType = "WEIXIN"
        self.setDestCityInfo()
        
        search.delegate = self
        
        tableView = UITableView.init(frame: CGRect(x: 0, y: 0, width: 0, height: 0), style: .plain)
        tableView.backgroundColor = UIColor.init(hex: "#f3f3f3")
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(GTPlaceOrderCell.self, forCellReuseIdentifier: "GTPlaceOrderCell")
        tableView.register(GTPlaceOrderSectionHeaderCell.self, forCellReuseIdentifier: "GTPlaceOrderSectionHeaderCell")
        tableView.register(GTPlaceOrderBaggageCell.self, forCellReuseIdentifier: "GTPlaceOrderBaggageCell")
        tableView.register(GTPlaceOrderNotesCell.self, forCellReuseIdentifier: "GTPlaceOrderNotesCell")
        tableView.register(OrderTaskDetailBaggageCell.self, forCellReuseIdentifier: "OrderTaskDetailBaggageCell")

        tableView.estimatedRowHeight = 50
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.separatorStyle = .none
        tableView.tableFooterView = UIView.init()
        self.view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.top.left.right.equalTo(0)
        }
        
        priceView = GTPlaceOrderPriceView.init(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        priceView.showPriceDetail = { (flag) in
            self.showPriceDetailView(flag)
        }
        priceView.commitOrder = {
            self.commitOrder()
        }
        self.view.addSubview(priceView)
        priceView.snp.makeConstraints { (make) in
            make.left.bottom.right.equalTo(0)
            make.top.equalTo(tableView.snp.bottom)
        }
        
        
        priceDetailView = GTPlaceOrderPriceDetailView.init(Int(self.placeOrderModel.distance)!, self.placeOrderModel.baggageNumber, self.placeOrderModel.safeTag, 0)
        priceDetailView.dismissView = {
            self.showPriceDetailView(false)
        }
        self.view.addSubview(priceDetailView)
        priceDetailView.snp.makeConstraints { (make) in
            make.left.right.equalTo(0)
            make.height.equalTo(tableView)
            make.top.equalTo(tableView.snp.bottom)
        }
        
        self.view.bringSubview(toFront: priceView)
        
        let sendDate = Date.mySendDate()
        self.selectDate(sendDate[0], displayDate: sendDate[1], hour: sendDate[2], minute: sendDate[3], style: .date_send)
        self.selectReceiveType(type: "酒店");
        self.setRecipientType("本人")
//        self.updateItemDetailTexts()
    }
    
    // MARK: - 提交订单
    func commitOrder() {
        
        let tuple = self.placeOrderModel.placeModelIsEmpty()
        if tuple.0 {
            LPPopup.popupCustomText(tuple.1)
            return
        }
        
        if placeOrderModel.judgeBaggages(baggages) {
            let alert = UIAlertController(title: "是否已付款?", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "否", style: .default, handler: { (action) in
                //
                let para = self.placeOrderModel.placeModelParameter(self.baggages, "WAITPAY")
                
                self.placeOrder(para)
                
            }))
            alert.addAction(UIAlertAction(title: "是", style: .default, handler: { (action) in
                
                self.placeOrder(self.placeOrderModel.placeModelParameter(self.baggages, "PREPAID"))
            }))
            
            self.present(alert, animated: true, completion: nil)
            
        } else {
            LPPopup.popupCustomText("请完善行李信息")
        }
        
    }
    
    func placeOrder(_ para: [AnyHashable:Any]) {
        OrderRequest_swift.gtPlaceOrder(withParameters: para, success: { (responseObject) in
            LPPopup.popupCustomText("下单成功")
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()+1.0, execute: {
                self.navigationController?.popViewController(animated: true)
            })
        }) { (error) in
            //
        }
    }
    
    func showPriceDetailView(_ flag: Bool) {
        
        if flag {
            UIView.animate(withDuration: 0.25, animations: {
                self.priceDetailView.snp.remakeConstraints { (make) in
                    make.left.right.equalTo(0)
                    make.height.equalTo(self.tableView)
                    make.top.equalTo(self.tableView.snp.top)
                }
                self.view.layoutIfNeeded()
                
            }) { (_) in
                self.priceDetailView.bgView.isHidden = false
            }
        } else {
            self.priceDetailView.bgView.isHidden = true
            
            UIView.animate(withDuration: 0.25) {
                self.priceDetailView.snp.remakeConstraints { (make) in
                    make.left.right.equalTo(0)
                    make.height.equalTo(self.tableView)
                    make.top.equalTo(self.tableView.snp.bottom)
                }
                self.view.layoutIfNeeded()
            }
            
        }
        
        self.priceView.flag = flag
        
    }
    
    func setDestCityInfo() {
        self.placeOrderModel.receiveCity = (BGWUser.current()?.userRole.provinceName ?? "") + " " + (BGWUser.current()?.userRole.cityName ?? "")
        self.placeOrderModel.destProvinceName = self.placeOrderModel.srcProvinceName
        self.placeOrderModel.destProvinceId = self.placeOrderModel.srcProvinceId
        self.placeOrderModel.destCityName = self.placeOrderModel.srcCityName
        self.placeOrderModel.destCityId = self.placeOrderModel.srcCityId
    }
    
    func setReceiveType(_ type: String) {
        switch type {
        case "机场":
            receive_type = .airport
            self.placeOrderModel.destAddressType = "SERVICECERTER"
            self.placeOrderModel.receiveMailingWay = "AIRPOSTCOUNTER"
            break
        case "酒店":
            receive_type = .hotel
            self.placeOrderModel.destAddressType = "HOTEL"
//            self.placeOrderModel.receiveMailingWay = "FRONTDESK"
            break
        case "住宅":
            receive_type = .house
            self.placeOrderModel.destAddressType = "RESIDENCE"
            break
        default:
            break
        }
    }
    
    func setRecipientType(_ type: String) {
        switch type {
        case "本人":
            recipient_type = .oneSelf
            self.placeOrderModel.receiveMailingWay = "ONESELF"
            break
        case "他人":
            recipient_type = .others
            self.placeOrderModel.receiveMailingWay = "OTHER"
            //清空收件人信息
            self.placeOrderModel.receiverIdNumber = ""
            self.placeOrderModel.receiverName = ""
            self.placeOrderModel.receiverPhone = ""
            break
        default:
            break
        }
    }


}
