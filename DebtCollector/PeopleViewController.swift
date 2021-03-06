import UIKit
import RxSwift
import RxCocoa
import SCLAlertView
import RxRealm

class PeopleViewController: UITableViewController {
    let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        tableView.dataSource = nil
        tableView.delegate = nil
        Observable.collection(from: RealmWrapper.shared.people.sorted(byKeyPath: "name"))
            .bind(to: tableView.rx.items(cellIdentifier: "cell")) {
                index, person, cell in
                cell.textLabel?.text = person.name
        }.disposed(by: disposeBag)
        
        tableView.rx.modelSelected(Person.self).subscribe(onNext: {
            [weak self] person in
            self?.performSegue(withIdentifier: "showPerson", sender: person)
            if let selectedIndexPath = self?.tableView.indexPathForSelectedRow {
                self?.tableView.deselectRow(at: selectedIndexPath, animated: true)
            }
        }).disposed(by: disposeBag)
        
        self.navigationController?.navigationBar.tintColor = UIColor.white
        
        if UserSettings.readOnlyMode {
            self.navigationItem.rightBarButtonItems = []
        }
    }
    
    @IBAction func addPerson() {
        if UserSettings.readOnlyMode {
            let alert = SCLAlertView()
            alert.showWarning("Read Only Mode", subTitle: "You cannot add people in read only mode", closeButtonTitle: "OK")
            return
        }
        
        let alert = SCLAlertView(appearance: SCLAlertView.SCLAppearance(showCloseButton: false))
        let nameField = alert.addTextField("Name")
        alert.addButton("OK", action: {
            if nameField.text?.trimmed() == "" {
                return
            }
            
            if RealmWrapper.shared.people.contains(where: { $0.name == nameField.text!.trimmed() }) {
                let errorAlert = SCLAlertView()
                errorAlert.showError("Error", subTitle: "A person with this name already exists!")
                return
            }
            let newPerson = Person()
            newPerson.name = nameField.text!.trimmed()
            try! RealmWrapper.shared.realm.write {
                RealmWrapper.shared.realm.add(newPerson)
            }
        })
        alert.addButton("Cancel", action: {})
        alert.showEdit("New Person", subTitle: "Please enter the name of the person:")
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let vc = segue.destination as? PersonViewController {
            vc.person = (sender as! Person)
        }
    }
}
