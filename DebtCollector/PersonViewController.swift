import UIKit
import RxCocoa
import RxSwift
import RxRealm
import RxDataSources
import SCLAlertView

class PersonViewController : UITableViewController {
    let disposeBag = DisposeBag()
    
    var person: Person!
    
    override func viewDidLoad() {
        title = person.name
        
        tableView.dataSource = nil
        tableView.delegate = nil
        tableView.register(UINib(nibName: "BriefTransactionTableViewCell", bundle: nil), forCellReuseIdentifier: "transactionCell")
        
        let dataSource = RxTableViewSectionedReloadDataSource<PersonTableViewSection>(configureCell:  {
            ds, tv, ip, item in
            switch item {
            case .transaction(let transaction):
                let cell = tv.dequeueReusableCell(withIdentifier: "transactionCell") as! BriefTransactionTableViewCell
                let formatter1 = NumberFormatter()
                formatter1.numberStyle = .currency
                formatter1.currencySymbol = UserSettings.currencySymbol
                cell.amountLabel.text = formatter1.string(from: abs(transaction.amount.value ?? 0) as NSNumber)
                cell.borrowedReturnedLabel.text = transaction.amount.value ?? 0 < 0 ? "Returned" : "Borrowed"
                let formatter2 = DateFormatter()
                formatter2.dateStyle = .short
                formatter2.timeStyle = .none
                cell.dateLabel.text = formatter2.string(from: transaction.date)
                cell.transactionLabel.text = transaction.parentTransactions.first!.title
                cell.selectionStyle = .gray
                if transaction.amount.value ?? 0 < 0 {
                    cell.contentView.backgroundColor = UIColor.green.withAlphaComponent(0.5)
                } else if transaction.amount.value ?? 0 > 0 {
                    cell.contentView.backgroundColor = UIColor.red.withAlphaComponent(0.5)
                }
                
                if transaction.details.trimmed() != "" {
                    cell.transactionDetailsLabel.text = transaction.details
                } else {
                    cell.transactionDetailsLabel.removeFromSuperview()
                }
                
                return cell
            case .button(title: let title, tint: let tint):
                let cell = tv.dequeueReusableCell(withIdentifier: "buttonCell")
                cell!.textLabel!.text = title
                cell!.textLabel?.textColor = tint
                return cell!
            }
        })
        
        Observable.collection(from: RealmWrapper.shared.transactions.filter("personName == %@", person.name).sorted(byKeyPath: "date", ascending: true))
            .map { (transactions) -> [PersonTableViewSection] in
                var sections = [
                    PersonTableViewSection.buttonSection(rows: [.button(title: "Delete This Person", tint: .red)])
                ]
                
                if UserSettings.readOnlyMode {
                    sections = []
                }
                
                sections.append(.transactionSection(rows: transactions.toArray().map { .transaction($0) }))
                return sections
        }
        .bind(to: tableView.rx.items(dataSource: dataSource))
        .disposed(by: disposeBag)
        
        tableView.rx.modelSelected(PersonTableViewSection.PersonTableViewRow.self).subscribe { [weak self] model in
            guard let modelNonNil = model.element else { return }
            guard let `self` = self else { return }
            switch modelNonNil {
            case .button(title: "Delete This Person", _):
                let alert = SCLAlertView(appearance: SCLAlertView.SCLAppearance(showCloseButton: false))
                alert.addButton("Yes", action: {
                    self.deletePerson()
                })
                alert.addButton("No", action: {})
                alert.showWarning("Delete Person", subTitle: "Do you really want to delete this person?")
                if let selectedIndexPath = self.tableView.indexPathForSelectedRow {
                    self.tableView.deselectRow(at: selectedIndexPath, animated: true)
                }
            case .transaction(let transaction):
                self.performSegue(withIdentifier: "showWholeTransaction", sender: transaction.parentTransactions.first)
            default:
                return
            }
        }.disposed(by: disposeBag)
    }
    
    func deletePerson() {
        if UserSettings.readOnlyMode {
            let alert = SCLAlertView()
            alert.showWarning("Read Only Mode", subTitle: "You cannot delete people in read only mode", closeButtonTitle: "OK")
            return
        }
        try! RealmWrapper.shared.realm.write {
            RealmWrapper.shared.realm.delete(self.person)
        }
        navigationController?.popViewController(animated: true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let vc = segue.destination as? DetailTransactionViewController {
            vc.groupedTransaction = sender as? GroupTransaction
        }
    }
}

enum PersonTableViewSection : SectionModelType {
    case buttonSection(rows: [PersonTableViewRow])
    case transactionSection(rows: [PersonTableViewRow])
    
    var items: [PersonTableViewSection.PersonTableViewRow] {
        switch self {
        case .buttonSection(rows: let rows):
            return rows
        case .transactionSection(rows: let rows):
            return rows
        }
    }
    
    init(original: PersonTableViewSection, items: [PersonTableViewSection.PersonTableViewRow]) {
        switch original {
        case .buttonSection(rows: _):
            self = .buttonSection(rows: items)
        case .transactionSection(rows: _):
            self = .transactionSection(rows: items)
        }
    }
    
    typealias Item = PersonTableViewRow
    
    enum PersonTableViewRow {
        case button(title: String, tint: UIColor)
        case transaction(Transaction)
    }
}
