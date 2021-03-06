import UIKit
import Eureka
import RealmSwift

class GenerateReportController: FormViewController {
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let section = Section("select range")
        section <<< PickerInlineRow<String>(tagRange) {
            row in
            row.title = "Range"
            row.options = [last7Days, last14Days, last30Days, last90Days, last365Days, allTime, custom]
            row.value = last7Days
        }
        
        section <<< DateInlineRow(tagStartDate) {
            row in
            row.title = "From"
            row.value = Date().addingTimeInterval(-86400 * 7)
            row.hidden = .function([tagRange], { ($0.rowBy(tag: tagRange) as! RowOf<String>).value != custom })
        }
        
        section <<< DateInlineRow(tagEndDate) {
            row in
            row.title = "To"
            row.value = Date()
            row.hidden = .function([tagRange], { ($0.rowBy(tag: tagRange) as! RowOf<String>).value != custom })
        }
        
        form +++ section
        form +++ ButtonRow() {
            row in
            row.title = "Generate Report"
            row.disabled = .function([tagRange, tagStartDate, tagEndDate], { (form) -> Bool in
                guard let range = (form.rowBy(tag: tagRange) as! RowOf<String>).value else { return true }
                guard let start = (form.rowBy(tag: tagStartDate) as! RowOf<Date>).value else { return true }
                guard let end = (form.rowBy(tag: tagEndDate) as! RowOf<Date>).value else { return true }
                return range == custom && start >= end
            })
        }
        .onCellSelection({ [unowned self] (cell, row) in
            let row = self.form.rowBy(tag: tagRange) as! RowOf<String>
            if row.value == custom {
                let start = (self.form.rowBy(tag: tagStartDate) as! RowOf<Date>).value!
                let end = (self.form.rowBy(tag: tagEndDate) as! RowOf<Date>).value!
                if start < end {
                    self.performSegue(withIdentifier: "showReport", sender: (start, end))
                }
            } else if row.value == allTime {
                self.performSegue(withIdentifier: "showReport", sender: nil)
            } else {
                let dict = [
                    last7Days: 7,
                    last14Days: 14,
                    last30Days: 30,
                    last90Days: 90,
                    last365Days: 365
                ]
                let end = Date()
                let start = end.addingTimeInterval(-86400 * Double(dict[row.value!]!))
                self.performSegue(withIdentifier: "showReport", sender: (start, end))
            }
        })
        
        self.navigationController?.navigationBar.tintColor = UIColor.white
        navigationController?.updateReadOnlyModePrompt()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let vc = segue.destination as? ReportController {
            let results: Results<GroupTransaction>
            if let (start, end) = sender as? (Date, Date) {
                results = RealmWrapper.shared.groupTransactions.filter("date BETWEEN {%@, %@}", start, end)
            } else {
                results = RealmWrapper.shared.groupTransactions
            }
            let report = Report(groupTransactions: Array(results))
            vc.report = report
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        navigationController?.updateReadOnlyModePrompt()
    }
}

// MARK: Date Range Options

let last7Days = "Last 7 Days"
let last14Days = "Last 14 Days"
let last30Days = "Last 30 Days"
let last90Days = "Last 90 Days"
let last365Days = "Last 365 Days"
let allTime = "All Time"
let custom = "Custom"

// MARK: Form Tags

let tagRange = "range"
let tagStartDate = "startDate"
let tagEndDate = "endDate"
