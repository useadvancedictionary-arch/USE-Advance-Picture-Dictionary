plugins {
    id("com.android.asset-pack")
}

assetPack {
    packName.set("cards_pack")
    dynamicDelivery {
        deliveryType.set("install-time")
    }
}

// Ensure cards folder exists from root assets/cards if not already symlinked/junctioned
val syncCardsToAssetPack by tasks.registering(Sync::class) {
    from(rootProject.file("../assets/cards"))
    into("src/main/assets/cards")
    // Only copy if the target directory doesn't already contain files
    onlyIf {
        val destDir = file("src/main/assets/cards")
        !destDir.exists() || (destDir.listFiles()?.isEmpty() == true)
    }
}

tasks.matching { it.name.contains("AssetPack") || it.name.contains("PreBundle") || it.name.contains("Package") }.configureEach {
    dependsOn(syncCardsToAssetPack)
}
