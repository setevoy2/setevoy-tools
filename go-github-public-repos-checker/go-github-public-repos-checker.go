package main

import (
	"os"
	"context"
    "fmt"
	"strings"
    "github.com/google/go-github/github"
	"github.com/ashwanthkumar/slack-go-webhook"
)

func sendSlackAlarm(repoName string, repoUrl string) {

    webhookUrl := os.Getenv("SLACK_URL")

    text := fmt.Sprintf(":scream: *ALARM*: repository `%s` was NOT found in Allowed!", repoName)

    attachment := slack.Attachment{}
    attachment.AddAction(slack.Action{Type: "button", Text: "RepoURL", Url: repoUrl, Style: "danger"}) 

    payload := slack.Payload{
        Username:    "Github checker",
        Text:        text,
        Channel:     os.Getenv("SLACK_CHANNEL"),
        IconEmoji:   ":scream:",
        Attachments: []slack.Attachment{attachment},
    }

    err := slack.Send(webhookUrl, "", payload)
    if len(err) > 0 {
        fmt.Printf("error: %s\n", err)
    }
}

func isAllowedRepo(repoName string, allowedRepos []string) bool {

    for _, i := range allowedRepos {
        if i == repoName {
			return true
        }
	}

	return false
}

func main() {

    client := github.NewClient(nil)

    opt := &github.RepositoryListByOrgOptions{Type: "public"}
    repos, _, _ := client.Repositories.ListByOrg(context.Background(), os.Getenv("GITHUB_ORG_NAME"), opt)

	allowedRepos := strings.Fields(os.Getenv("ALLOWED_REPOS"))

	for _, repo := range repos {
		fmt.Printf("\nChecking %s\n", *repo.Name)
		if isAllowedRepo(*repo.Name, allowedRepos) {
			fmt.Printf("OK: repo %s found in Allowed\n", *repo.Name)
		} else {
			fmt.Printf("ALARM: repo %s was NOT found in Allowed!\n", *repo.Name)
			sendSlackAlarm(*repo.Name, *repo.HTMLURL)
		}
	}
}
