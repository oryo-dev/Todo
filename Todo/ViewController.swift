//
//  ViewController.swift
//  Todo
//
//  Created by oryo on 2022/06/17.
//

import UIKit
import Firebase

struct Todo {
    let id: String
    let todo: String
    let createdAt: Timestamp
    
    init(dic: [String: Any]) {
        self.id = dic["id"] as! String
        self.todo = dic["todo"] as! String
        self.createdAt = dic["createdAt"] as! Timestamp
    }
}

enum LoginSigninAdd {
    case login
    case signin
    case add
    
    mutating func toggle() {
        switch self {
        case .login:
            self = .signin
        case .signin:
            self = .login
        case .add:
            return
        }
    }
}

class ViewController: UIViewController {
    
    @IBOutlet weak var logoutButton: UIBarButtonItem!
    @IBOutlet weak var addButton: UIBarButtonItem!
    @IBOutlet weak var todoTableView: UITableView!
    @IBOutlet weak var loginSigninAddView: UIView!
    @IBOutlet weak var loginSigninAddLabel: UILabel!
    @IBOutlet weak var emailTodoTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var confirmPasswordTextField: UITextField!
    @IBOutlet weak var toggleCancelButton: UIButton!
    @IBOutlet weak var loginSigninAddButton: UIButton!
    
    var handle: AuthStateDidChangeListenerHandle?
    var loginSigninAdd: LoginSigninAdd = .login
    var alertController: UIAlertController?
    let activityIndicatorView = UIActivityIndicatorView()
    var todos: [Todo] = [] {
        didSet {
            todoTableView.reloadData()
        }
    }
    var email = ""
    var uid = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.backgroundColor = .systemIndigo
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        
        todoTableView.delegate = self
        todoTableView.dataSource = self
        
        loginSigninAddView.isHidden = true
        loginSigninAddView.layer.cornerRadius = 10
        loginSigninAddView.layer.shadowColor = UIColor.gray.cgColor
        loginSigninAddView.layer.shadowOpacity = 1
        loginSigninAddView.layer.shadowRadius = 5
        loginSigninAddView.layer.shadowOffset = CGSize(width: 4, height: 4)
        
        emailTodoTextField.delegate = self
        passwordTextField.delegate = self
        confirmPasswordTextField.delegate = self
        
        loginSigninAddButton.isEnabled = false
        
        activityIndicatorView.center = view.center
        activityIndicatorView.style = .large
        activityIndicatorView.color = .gray
        
        view.addSubview(activityIndicatorView)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        activityIndicatorView.startAnimating()
        handle = Auth.auth().addStateDidChangeListener { auth, user in
            if auth.currentUser == nil || user == nil {
                self.assignToLoginSigninAddView()
                self.changeIsHiddenAndIsEnabled(false)
                self.activityIndicatorView.stopAnimating()
            } else {
                self.email = user!.email!
                self.uid = user!.uid
                self.title = self.email
                self.getTodos()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        Auth.auth().removeStateDidChangeListener(handle!)
    }
    
    @IBAction func logoutButtonAction(_ sender: Any) {
        activityIndicatorView.startAnimating()
        let firebaseAuth = Auth.auth()
        do {
            try firebaseAuth.signOut()
            loginSigninAdd = .login
            assignToLoginSigninAddView()
            changeIsHiddenAndIsEnabled(false)
            todos = []
            alert("ログアウトしました")
        } catch {
            alert("ログアウトできませんでした")
        }
        activityIndicatorView.stopAnimating()
    }
    
    @IBAction func addButtonAction(_ sender: Any) {
        loginSigninAdd = .add
        assignToLoginSigninAddView()
        changeIsHiddenAndIsEnabled(false)
    }
    
    @IBAction func toggleCancelButtonAction(_ sender: Any) {
        if loginSigninAdd == .add {
            title = email
            emailTodoTextField.text = ""
            changeIsHiddenAndIsEnabled(true)
        } else {
            loginSigninAdd.toggle()
            assignToLoginSigninAddView()
            blankCheck()
        }
    }
    
    @IBAction func loginSigninAddButtonAction(_ sender: Any) {
        activityIndicatorView.startAnimating()
        switch loginSigninAdd {
        case .login:
            Auth.auth().signIn(withEmail: emailTodoTextField.text!, password: passwordTextField.text!) { authResult, error in
                self.loginSignin(self.emailTodoTextField.text!, error)
            }
        case .signin:
            Auth.auth().createUser(withEmail: emailTodoTextField.text!, password: passwordTextField.text!) { authResult, error in
                self.loginSignin(self.emailTodoTextField.text!, error)
            }
        case .add:
            let data = [
                "id": UUID().uuidString,
                "todo": emailTodoTextField.text!,
                "createdAt": Timestamp()
            ] as [String : Any]
            Firestore.firestore().collection(uid).document(data["id"] as! String).setData(data) { error in
                if error != nil {
                    self.alert("データを追加できませんでした")
                    self.activityIndicatorView.stopAnimating()
                    return
                }
                self.getTodos()
                self.alert("データを追加しました")
                self.title = self.email
                self.emailTodoTextField.text = ""
                self.changeIsHiddenAndIsEnabled(true)
            }
        }
    }
    
    func assignToLoginSigninAddView() {
        title = assignAny("ログイン待ち...", "新規登録待ち...", "追加待ち...")
        loginSigninAddLabel.text = assignAny("ログイン", "新規登録", "追加")
        emailTodoTextField.placeholder = loginSigninAdd == .add ? "todo" : "email"
        toggleCancelButton.setTitle(assignAny("新規登録へ", "ログインへ", "キャンセル"), for: .normal)
        loginSigninAddButton.setTitle(assignAny("ログイン", "新規登録", "追加"), for: .normal)
        passwordTextField.isHidden = loginSigninAdd == .add ? true : false
        confirmPasswordTextField.isHidden = loginSigninAdd == .signin ? false : true
    }
    
    func assignAny(_ login: String, _ signin: String, _ add: String) -> String {
        switch loginSigninAdd {
        case .login:
            return login
        case .signin:
            return signin
        case .add:
            return add
        }
    }
    
    func loginSignin(_ email: String, _ error: Error?) {
        if error != nil {
            alert(loginSigninAdd == .login ? "ログインできませんでした" : "新規登録できませんでした")
            activityIndicatorView.stopAnimating()
            return
        }
        alert(loginSigninAdd == .login ? "ログインしました" : "新規登録しました")
        title = email
        emailTodoTextField.text = ""
        passwordTextField.text = ""
        confirmPasswordTextField.text = ""
        changeIsHiddenAndIsEnabled(true)
        activityIndicatorView.stopAnimating()
    }
    
    func alert(_ title: String) {
        alertController = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        present(alertController!, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.alertController!.dismiss(animated: true)
        }
    }
    
    func changeIsHiddenAndIsEnabled(_ bool: Bool) {
        loginSigninAddView.isHidden = bool
        logoutButton.isEnabled = bool
        addButton.isEnabled = bool
    }
    
    func getTodos() {
        Firestore.firestore().collection(self.uid).getDocuments { snapshot, error in
            if error != nil {
                self.alert("データを取得できませんでした")
                self.activityIndicatorView.stopAnimating()
                return
            }
            self.todos = snapshot!.documents.compactMap { Todo.init(dic: $0.data()) }
            self.todos = self.todos.sorted(by: {
                $0.createdAt.compare($1.createdAt) == .orderedAscending
            })
            self.activityIndicatorView.stopAnimating()
        }
    }
}

extension ViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return todos.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        let todoLabel = cell.contentView.viewWithTag(1) as! UILabel
        let dateLabel = cell.contentView.viewWithTag(2) as! UILabel
        
        todoLabel.text = todos[indexPath.row].todo
        dateLabel.text = createdAtToString(todos[indexPath.row].createdAt)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            activityIndicatorView.startAnimating()
            Firestore.firestore().collection(uid).document(todos[indexPath.row].id).delete() { error in
                if error != nil {
                    self.alert("データを削除できませんでした")
                    self.activityIndicatorView.stopAnimating()
                    return
                }
                self.getTodos()
                self.alert("データを削除しました")
                self.activityIndicatorView.stopAnimating()
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }
    
    func createdAtToString(_ createdAt: Timestamp) -> String {
        let date = createdAt.dateValue()
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.locale = Locale(identifier: "ja_JP")
        dateFormatter.timeZone = TimeZone(identifier:  "Asia/Tokyo")
        dateFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return dateFormatter.string(from: date)
    }
}

extension ViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidChangeSelection(_ textField: UITextField) {
        blankCheck()
    }
    
    func blankCheck() {
        guard let emailTodo = emailTodoTextField.text else { return }
        guard let password = passwordTextField.text else { return }
        guard let confirmPassword = confirmPasswordTextField.text else { return }
        
        switch loginSigninAdd {
        case .login:
            changeIsEnabled(emailTodo.isEmpty || password.isEmpty)
        case .signin:
            changeIsEnabled(emailTodo.isEmpty || password.isEmpty || confirmPassword.isEmpty || password != confirmPassword)
        case .add:
            changeIsEnabled(emailTodo.isEmpty)
        }
    }
    
    func changeIsEnabled(_ bool: Bool) {
        if bool {
            loginSigninAddButton.isEnabled = false
        } else {
            loginSigninAddButton.isEnabled = true
        }
    }
}
