/*
Copyright © 2025 NAME HERE <EMAIL ADDRESS>
*/
package cmd

import (
	"fmt"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"

	"github.com/spf13/cobra"
)

// operateBinariesCmd represents the operateBinaries command
var operateBinariesCmd = &cobra.Command{
	Use:   "operateBinaries",
	Short: "Build and install Go binaries from multiple repos",
	Long:  `For each repo, runs 'make all' and moves the resulting binary to /usr/local/bin.`,
	Run: func(cmd *cobra.Command, args []string) {
		usr, _ := user.Current() // get current user
		repos := []string{
			"/home/" + usr.Username + "/aether-forks/amf",
			"/home/" + usr.Username + "/aether-forks/ausf",
			"/home/" + usr.Username + "/aether-forks/nrf",
			"/home/" + usr.Username + "/aether-forks/nssf",
			"/home/" + usr.Username + "/aether-forks/pcf",
			"/home/" + usr.Username + "/aether-forks/simapp",
			"/home/" + usr.Username + "/aether-forks/smf",
			"/home/" + usr.Username + "/aether-forks/udm",
			"/home/" + usr.Username + "/aether-forks/udr",
			// Agrega aquí las rutas de tus repos
		}

		for _, repo := range repos {
			fmt.Printf("Building in repo: %s\n", repo)
			// Ejecutar 'make all'
			makeCmd := exec.Command("make", "all")
			makeCmd.Dir = repo
			makeCmd.Stdout = os.Stdout
			makeCmd.Stderr = os.Stderr
			if err := makeCmd.Run(); err != nil {
				fmt.Printf("Error running make in %s: %v\n", repo, err)
				continue
			}

			// Buscar el binario generado (asume que está en repo y se llama igual que el repo)
			repoName := filepath.Base(repo)
			binPath := filepath.Join(repo, repoName)
			if _, err := os.Stat(binPath); os.IsNotExist(err) {
				// Si el binario no existe, buscar en repo/bin/
				binPath = filepath.Join(repo, "bin", repoName)
				if _, err := os.Stat(binPath); os.IsNotExist(err) {
					fmt.Printf("No se encontró binario en %s\n", binPath)
					continue
				}
			}

			// Mover el binario a /usr/local/bin
			destPath := filepath.Join("/usr/local/bin", repoName)
			moveCmd := exec.Command("sudo", "mv", binPath, destPath)
			moveCmd.Stdout = os.Stdout
			moveCmd.Stderr = os.Stderr
			if err := moveCmd.Run(); err != nil {
				fmt.Printf("Error moviendo binario a /usr/local/bin: %v\n", err)
				continue
			}
			fmt.Printf("Binario instalado en %s\n", destPath)
		}
	},
}

func init() {
	rootCmd.AddCommand(operateBinariesCmd)

	// Here you will define your flags and configuration settings.

	// Cobra supports Persistent Flags which will work for this command
	// and all subcommands, e.g.:
	// operateBinariesCmd.PersistentFlags().String("foo", "", "A help for foo")

	// Cobra supports local flags which will only run when this command
	// is called directly, e.g.:
	// operateBinariesCmd.Flags().BoolP("toggle", "t", false, "Help message for toggle")
}
