// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title MultisigGovernance
 * @dev Contrat simple de gouvernance multi-signature permettant à plusieurs signataires
 * d'approuver et d'exécuter des propositions collectivement.
 */
contract MultisigGovernance {
    
    // ==================== Structures ====================
    
    /// @dev Structure représentant une proposition
    struct Proposal {
        uint256 id;                    // Identifiant unique de la proposition
        address target;                // Adresse cible pour l'appel
        bytes data;                    // Données de l'appel (fonction signature + paramètres)
        uint256 requiredApprovals;     // Nombre d'approbations requises
        uint256 approvalCount;         // Nombre d'approbations actuelles
        bool executed;                 // Statut d'exécution
        mapping(address => bool) approvers; // Suivi des signataires qui ont approuvé
    }
    
    // ==================== Variables d'état ====================
    
    mapping(uint256 => Proposal) public proposals;  // Stockage des propositions
    mapping(address => bool) public signers;        // Signataires autorisés
    address[] public signersList;                   // Liste des signataires
    
    uint256 public proposalCount = 0;               // Compteur de propositions
    uint256 public quorum;                          // Seuil d'approbation requis par défaut
    
    // ==================== Événements ====================
    
    /// @dev Émis quand une nouvelle proposition est créée
    event ProposalSubmitted(uint256 indexed proposalId, address indexed target, bytes data);
    
    /// @dev Émis quand un signataire approuve une proposition
    event ProposalApproved(uint256 indexed proposalId, address indexed signer, uint256 approvalsCount);
    
    /// @dev Émis quand une proposition est exécutée
    event ProposalExecuted(uint256 indexed proposalId, bool success, bytes result);
    
    // ==================== Modifieurs ====================
    
    /// @dev Vérifie que l'appelant est un signataire autorisé
    modifier onlySigner() {
        require(signers[msg.sender], "Seul un signataire autorise peut appeler cette fonction");
        _;
    }
    
    /// @dev Vérifie que la proposition existe
    modifier proposalExists(uint256 proposalId) {
        require(proposalId < proposalCount, "La proposition n'existe pas");
        _;
    }
    
    /// @dev Vérifie que la proposition n'a pas déjà été exécutée
    modifier notExecuted(uint256 proposalId) {
        require(!proposals[proposalId].executed, "La proposition a deja ete executee");
        _;
    }
    
    // ==================== Constructeur ====================
    
    /**
     * @dev Initialise le contrat avec les signataires et le seuil d'approbation
     * @param initialSigners Tableau des adresses des signataires initiaux
     * @param _quorum Nombre d'approbations requises pour exécuter une proposition
     */
    constructor(address[] memory initialSigners, uint256 _quorum) {
        require(initialSigners.length > 0, "Au moins un signataire est requis");
        require(_quorum > 0 && _quorum <= initialSigners.length, 
                "Le seuil d'approbation doit etre entre 1 et le nombre de signataires");
        
        // Ajouter les signataires initiaux
        for (uint256 i = 0; i < initialSigners.length; i++) {
            address signer = initialSigners[i];
            require(signer != address(0), "Adresse signataire invalide");
            require(!signers[signer], "Signataire duplique");
            
            signers[signer] = true;
            signersList.push(signer);
        }
        
        quorum = _quorum;
    }
    
    // ==================== Fonctions principales ====================
    
    /**
     * @dev Soumet une nouvelle proposition
     * @param target Adresse cible pour l'appel
     * @param data Données de l'appel
     */
    function submitProposal(address target, bytes memory data) external onlySigner {
        require(target != address(0), "Adresse cible invalide");
        
        uint256 proposalId = proposalCount;
        
        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.target = target;
        newProposal.data = data;
        newProposal.requiredApprovals = quorum;
        newProposal.approvalCount = 0;
        newProposal.executed = false;
        
        proposalCount++;
        
        emit ProposalSubmitted(proposalId, target, data);
    }
    
    /**
     * @dev Approuve une proposition
     * @param proposalId Identifiant de la proposition à approuver
     */
    function approveProposal(uint256 proposalId) 
        external 
        onlySigner 
        proposalExists(proposalId) 
        notExecuted(proposalId) 
    {
        Proposal storage proposal = proposals[proposalId];
        
        // Vérifier que le signataire n'a pas déjà approuvé
        require(!proposal.approvers[msg.sender], "Vous avez deja approuve cette proposition");
        
        // Enregistrer l'approbation
        proposal.approvers[msg.sender] = true;
        proposal.approvalCount++;
        
        emit ProposalApproved(proposalId, msg.sender, proposal.approvalCount);
    }
    
    /**
     * @dev Exécute une proposition si le seuil d'approbation est atteint
     * @param proposalId Identifiant de la proposition à exécuter
     */
    function executeProposal(uint256 proposalId) 
        external 
        onlySigner 
        proposalExists(proposalId) 
        notExecuted(proposalId) 
    {
        Proposal storage proposal = proposals[proposalId];
        
        // Vérifier que le seuil d'approbation est atteint
        require(
            proposal.approvalCount >= proposal.requiredApprovals,
            "Nombre d'approbations insuffisant pour executer cette proposition"
        );
        
        // Marquer comme exécutée avant l'appel (protection contre la réentrance)
        proposal.executed = true;
        
        // Exécuter l'appel
        (bool success, bytes memory result) = proposal.target.call(proposal.data);
        
        emit ProposalExecuted(proposalId, success, result);
        
        require(success, "L'execution de la proposition a echoue");
    }
    
    // ==================== Fonctions de consultation ====================
    
    /**
     * @dev Retourne les détails d'une proposition
     * @param proposalId Identifiant de la proposition
     */
    function getProposal(uint256 proposalId) 
        external 
        view 
        proposalExists(proposalId) 
        returns (
            uint256 id,
            address target,
            bytes memory data,
            uint256 requiredApprovalsCount,
            uint256 approvalCount,
            bool executed
        ) 
    {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.id,
            proposal.target,
            proposal.data,
            proposal.requiredApprovals,
            proposal.approvalCount,
            proposal.executed
        );
    }
    
    /**
     * @dev Retourne la liste des signataires
     */
    function getSigners() external view returns (address[] memory) {
        return signersList;
    }
    
    /**
     * @dev Vérifie si une adresse a approuvé une proposition
     * @param proposalId Identifiant de la proposition
     * @param signer Adresse du signataire
     */
    function hasApproved(uint256 proposalId, address signer) 
        external 
        view 
        proposalExists(proposalId) 
        returns (bool) 
    {
        return proposals[proposalId].approvers[signer];
    }
}
