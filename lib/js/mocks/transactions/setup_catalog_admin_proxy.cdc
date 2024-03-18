import NFTCatalogAdmin from "../../../../contracts/utility/NFTCatalog.cdc"

transaction() {
    
    prepare(acct: AuthAccount) {
        acct.save(<- NFTCatalogAdmin.createAdminProxy(), to: NFTCatalogAdmin.AdminProxyStoragePath)
        acct.link<&NFTCatalogAdmin.AdminProxy{NFTCatalogAdmin.IAdminProxy}>(NFTCatalogAdmin.AdminProxyPublicPath, target: NFTCatalogAdmin.AdminProxyStoragePath)
    }
}