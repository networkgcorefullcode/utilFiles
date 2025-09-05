/*
Copyright © 2025 NAME HERE <EMAIL ADDRESS>
*/
package cmd

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/spf13/cobra"
)

// installmongoCmd represents the installmongo command
var installmongoCmd = &cobra.Command{
	Use:   "installmongo",
	Short: "Install and configure MongoDB with ReplicaSet",
	Long: `This command will install MongoDB 7.0, configure it for ReplicaSet usage,
and initialize a single-node ReplicaSet. Steps include:
1. Installing MongoDB
2. Configuring ReplicaSet
3. Initializing ReplicaSet
4. Verifying installation`,
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("Starting MongoDB installation and configuration...")

		// Step 1: Import MongoDB public key
		fmt.Println("🔹 Importing MongoDB public key...")
		importKeyCmd := `curl -fsSL https://pgp.mongodb.com/server-7.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor`
		if err := executeCommand(importKeyCmd); err != nil {
			fmt.Printf("❌ Error importing key: %v\n", err)
			return
		}

		// Step 2: Add MongoDB repository
		fmt.Println("🔹 Adding MongoDB repository...")
		addRepoCmd := `echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list`
		if err := executeCommand(addRepoCmd); err != nil {
			fmt.Printf("❌ Error adding repository: %v\n", err)
			return
		}

		// Step 3: Update and install MongoDB
		fmt.Println("🔹 Installing MongoDB...")
		updateCmd := "sudo apt update"
		installCmd := "sudo apt install -y mongodb-org"
		if err := executeCommand(updateCmd); err != nil {
			fmt.Printf("❌ Error updating apt: %v\n", err)
			return
		}
		if err := executeCommand(installCmd); err != nil {
			fmt.Printf("❌ Error installing MongoDB: %v\n", err)
			return
		}

		// Step 4: Enable and start MongoDB service
		fmt.Println("🔹 Configuring MongoDB service...")
		enableCmd := "sudo systemctl enable mongod"
		startCmd := "sudo systemctl start mongod"
		if err := executeCommand(enableCmd); err != nil {
			fmt.Printf("❌ Error enabling MongoDB service: %v\n", err)
			return
		}
		if err := executeCommand(startCmd); err != nil {
			fmt.Printf("❌ Error starting MongoDB service: %v\n", err)
			return
		}

		// Step 5: Configure ReplicaSet
		fmt.Println("🔹 Configuring ReplicaSet...")
		configContent := `
replication:
  replSetName: "rs0"

net:
  bindIp: 0.0.0.0
`
		if err := updateMongoConfig(configContent); err != nil {
			fmt.Printf("❌ Error configuring ReplicaSet: %v\n", err)
			return
		}

		// Step 6: Restart MongoDB
		fmt.Println("🔹 Restarting MongoDB...")
		restartCmd := "sudo systemctl restart mongod"
		if err := executeCommand(restartCmd); err != nil {
			fmt.Printf("❌ Error restarting MongoDB: %v\n", err)
			return
		}

		// Step 7: Initialize ReplicaSet
		fmt.Println("🔹 Initializing ReplicaSet...")
		initRsCmd := `mongosh --eval 'rs.initiate({_id:"rs0",members:[{_id:0,host:"localhost:27017"}]})'`
		if err := executeCommand(initRsCmd); err != nil {
			fmt.Printf("❌ Error initializing ReplicaSet: %v\n", err)
			return
		}

		fmt.Println("✅ MongoDB installation and configuration completed successfully!")
		fmt.Println("To verify the installation, run: mongosh --eval 'rs.status()'")
	},
}

// executeCommand ejecuta un comando shell y retorna error si falla
func executeCommand(command string) error {
	parts := strings.Fields(command)
	cmd := exec.Command(parts[0], parts[1:]...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

// updateMongoConfig actualiza el archivo de configuración de MongoDB
func updateMongoConfig(content string) error {
	configPath := "/etc/mongod.conf"

	// Hacer backup del archivo original
	backupCmd := fmt.Sprintf("sudo cp %s %s.backup", configPath, configPath)
	if err := executeCommand(backupCmd); err != nil {
		return fmt.Errorf("error creating backup: %v", err)
	}

	// Escribir nueva configuración
	tempFile := "/tmp/mongod.conf.new"
	if err := os.WriteFile(tempFile, []byte(content), 0644); err != nil {
		return fmt.Errorf("error writing temp config: %v", err)
	}

	// Mover el archivo temporal a la ubicación final
	moveCmd := fmt.Sprintf("sudo mv %s %s", tempFile, configPath)
	if err := executeCommand(moveCmd); err != nil {
		return fmt.Errorf("error updating config: %v", err)
	}

	return nil
}

func init() {
	rootCmd.AddCommand(installmongoCmd)

	// Here you will define your flags and configuration settings.

	// Cobra supports Persistent Flags which will work for this command
	// and all subcommands, e.g.:
	// intallmongoCmd.PersistentFlags().String("foo", "", "A help for foo")

	// Cobra supports local flags which will only run when this command
	// is called directly, e.g.:
	// intallmongoCmd.Flags().BoolP("toggle", "t", false, "Help message for toggle")
}
