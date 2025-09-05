/*
Copyright © 2025 NAME HERE <EMAIL ADDRESS>
*/
package cmd

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"
	"sync"

	"github.com/spf13/cobra"
)

// checkRepoCmd represents the checkRepo command
var checkRepoCmd = &cobra.Command{
	Use:   "checkRepo",
	Short: "check if the repos are cloned",
	Long: `check if the repos are cloned
and if not cloned then clone them`,

	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("checkRepo called")

		usr, err := user.Current() // get current user

		if err != nil { // manage error
			fmt.Println("Error getting current user:", err)
			return
		}

		repoDir := filepath.Join(usr.HomeDir, "aether-forks")

		err = os.Chdir(repoDir)
		if err != nil {
			fmt.Println("Error changing directory:", err)

			os.Mkdir(repoDir, 0755) // create directory if not exists

			err = os.Chdir(repoDir) // change directory
			if err != nil {
				fmt.Println("Error changing directory after creating it:", err)
				return
			}

			fmt.Println("Created and changed directory to:", repoDir)
			fmt.Println("Cloning repositories...")

			err = cloneRepo(githubUser, githubToken)
			if err != nil {
				fmt.Println("Error cloning repositories:", err)
				return
			}

		}

		fmt.Println("Changed directory to:", repoDir)
	},
}

var githubUser string
var githubToken string

func init() {
	rootCmd.AddCommand(checkRepoCmd)

	checkRepoCmd.Flags().StringVarP(&githubUser, "user", "u", "", "GitHub username")
	checkRepoCmd.Flags().StringVarP(&githubToken, "token", "k", "", "GitHub API token")
}

func cloneRepo(gituser, gittoken string) error {
	githubUser := "networkgcorefullcode"
	apiURL := fmt.Sprintf("https://api.github.com/users/%s/repos?per_page=100", githubUser)

	resp, err := http.Get(apiURL)
	if err != nil {
		fmt.Println("Error fetching repos:", err)
		return err
	}
	defer resp.Body.Close()

	var repos []struct {
		CloneURL string `json:"clone_url"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&repos); err != nil {
		fmt.Println("Error decoding response:", err)
		return err
	}
	waitGroup := sync.WaitGroup{}
	for _, repo := range repos {
		waitGroup.Add(1)
		go func() {
			defer waitGroup.Done()
			fmt.Printf("Cloning %s...\n", repo.CloneURL)
			if githubUser != "" && githubToken != "" {
				authURL := fmt.Sprintf("https://%s:%s@%s", gituser, gittoken, repo.CloneURL[8:])
				cmd := exec.Command("git", "clone", authURL)
				cmd.Stdout = os.Stdout
				cmd.Stderr = os.Stderr
				if err := cmd.Run(); err != nil {
					fmt.Printf("Error cloning %s: %v\n", repo.CloneURL, err)
				}
			} else {
				cmd := exec.Command("git", "clone", repo.CloneURL)
				cmd.Stdout = os.Stdout
				cmd.Stderr = os.Stderr
				if err := cmd.Run(); err != nil {
					fmt.Printf("Error cloning %s: %v\n", repo.CloneURL, err)
				}
			}
			fmt.Printf("Successfully cloned %s\n", repo.CloneURL)
		}()
	}

	waitGroup.Wait()
	fmt.Println("All repositories processed.")
	return nil
}
