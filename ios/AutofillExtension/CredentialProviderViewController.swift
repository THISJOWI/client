import AuthenticationServices

class CredentialProviderViewController: ASCredentialProviderViewController {
    
    // MARK: - Properties
    private var passwords: [[String: Any]] = []
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Create a simple UI for password selection
        let label = UILabel()
        label.text = "THISJOWI Password Manager"
        label.font = .boldSystemFont(ofSize: 24)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancelar", for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelAction), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cancelButton)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 50),
            
            cancelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cancelButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30)
        ])
    }
    
    // MARK: - ASCredentialProviderViewController Methods
    
    /// Called when the user selects a credential from QuickType bar
    override func provideCredentialWithoutUserInteraction(for credentialIdentity: ASPasswordCredentialIdentity) {
        // Try to provide credential without showing UI
        // This requires the credential to be available in shared storage
        
        if let credential = getCredential(for: credentialIdentity) {
            extensionContext.completeRequest(withSelectedCredential: credential, completionHandler: nil)
        } else {
            // Need user interaction
            extensionContext.cancelRequest(withError: NSError(
                domain: ASExtensionErrorDomain,
                code: ASExtensionError.userInteractionRequired.rawValue
            ))
        }
    }
    
    /// Called when the extension needs to prepare credential list for QuickType
    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        // Load passwords and show selection UI
        loadPasswords()
        
        // Filter passwords based on service identifiers
        let filteredPasswords = passwords.filter { password in
            guard let website = password["website"] as? String else { return true }
            return serviceIdentifiers.contains { identifier in
                website.contains(identifier.identifier) || identifier.identifier.contains(website)
            }
        }
        
        // Show password picker UI
        showPasswordPicker(passwords: filteredPasswords.isEmpty ? passwords : filteredPasswords)
    }
    
    /// Called when user wants to configure the extension
    override func prepareInterfaceToProvideCredential(for credentialIdentity: ASPasswordCredentialIdentity) {
        // Prepare UI to provide the specific credential
        loadPasswords()
        showPasswordPicker(passwords: passwords)
    }
    
    // MARK: - Private Methods
    
    private func loadPasswords() {
        // Load passwords from shared UserDefaults (App Group)
        // Note: You need to set up an App Group to share data between the main app and extension
        if let sharedDefaults = UserDefaults(suiteName: "group.com.thisjowi.passwords"),
           let data = sharedDefaults.data(forKey: "passwords"),
           let passwordList = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            passwords = passwordList
        } else {
            passwords = []
        }
    }
    
    private func getCredential(for identity: ASPasswordCredentialIdentity) -> ASPasswordCredential? {
        loadPasswords()
        
        // Find matching credential
        for password in passwords {
            let id = password["id"] as? String ?? ""
            if id == identity.recordIdentifier {
                let username = password["username"] as? String ?? ""
                let passwordValue = password["password"] as? String ?? ""
                return ASPasswordCredential(user: username, password: passwordValue)
            }
        }
        
        return nil
    }
    
    private func showPasswordPicker(passwords: [[String: Any]]) {
        // Remove existing subviews
        view.subviews.forEach { $0.removeFromSuperview() }
        
        // Create table view for password selection
        let tableView = UITableView(frame: view.bounds, style: .insetGrouped)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "PasswordCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        // Add cancel button
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancelar", for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelAction), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cancelButton)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: cancelButton.topAnchor, constant: -10),
            
            cancelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cancelButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10)
        ])
        
        self.passwords = passwords
        tableView.reloadData()
    }
    
    @objc private func cancelAction() {
        extensionContext.cancelRequest(withError: NSError(
            domain: ASExtensionErrorDomain,
            code: ASExtensionError.userCanceled.rawValue
        ))
    }
    
    private func selectPassword(at index: Int) {
        guard index < passwords.count else { return }
        
        let password = passwords[index]
        let username = password["username"] as? String ?? ""
        let passwordValue = password["password"] as? String ?? ""
        
        let credential = ASPasswordCredential(user: username, password: passwordValue)
        extensionContext.completeRequest(withSelectedCredential: credential, completionHandler: nil)
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate

extension CredentialProviderViewController: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return passwords.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Selecciona una contraseña"
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PasswordCell", for: indexPath)
        
        let password = passwords[indexPath.row]
        cell.textLabel?.text = password["title"] as? String ?? "Sin título"
        cell.detailTextLabel?.text = password["username"] as? String ?? ""
        cell.accessoryType = .disclosureIndicator
        
        // Configure cell style
        var content = cell.defaultContentConfiguration()
        content.text = password["title"] as? String ?? "Sin título"
        content.secondaryText = password["username"] as? String ?? ""
        content.image = UIImage(systemName: "key.fill")
        cell.contentConfiguration = content
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        selectPassword(at: indexPath.row)
    }
}
