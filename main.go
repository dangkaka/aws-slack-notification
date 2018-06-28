package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"github.com/aws/aws-lambda-go/lambda"
	"log"
	"net/http"
	"os"
)

type Request struct {
	Records []struct {
		SNS struct {
			Type       string `json:"Type"`
			Timestamp  string `json:"Timestamp"`
			SNSMessage string `json:"Message"`
		} `json:"Sns"`
	} `json:"Records"`
}

type SNSMessage struct {
	AlarmName        string `json:"AlarmName"`
	AlarmDescription string `json:"AlarmDescription"`
	NewStateValue    string `json:"NewStateValue"`
	NewStateReason   string `json:"NewStateReason"`
	OldStateValue    string `json:"OldStateValue"`
}

type SlackMessage struct {
	Attachments []Attachment `json:"attachments"`
}

type Attachment struct {
	Color  string            `json:"color"`
	Fields []AttachmentField `json:"fields"`
}

type AttachmentField struct {
	Title string `json:"title"`
	Value string `json:"value"`
	Short bool   `json:"short"`
}

func handler(request Request) error {
	var snsMessage SNSMessage
	err := json.Unmarshal([]byte(request.Records[0].SNS.SNSMessage), &snsMessage)
	if err != nil {
		log.Println("Unmarshal error: ", err)
		return err
	}
	log.Printf("New alarm: %s - Reason: %s", snsMessage.AlarmName, snsMessage.NewStateReason)
	slackMessage := buildSlackMessage(snsMessage)
	err = postToSlack(slackMessage)
	if err != nil {
		log.Println("PostToSlack error: ", err)
		return err
	}
	log.Println("Notification has been sent")
	return nil
}

func buildSlackMessage(message SNSMessage) SlackMessage {
	status := map[string]string{"OK": "good", "INSUFFICIENT_DATA": "warning", "ALARM": "danger"}
	return SlackMessage{
		Attachments: []Attachment{
			Attachment{
				Color: status[message.NewStateValue],
				Fields: []AttachmentField{
					AttachmentField{"Alarm Name", message.AlarmName, true},
					AttachmentField{"Alarm Description", message.AlarmDescription, false},
					AttachmentField{"Alarm reason", message.NewStateReason, false},
					AttachmentField{"Old State", message.OldStateValue, true},
				},
			},
		},
	}
}

func postToSlack(message SlackMessage) error {
	client := &http.Client{}
	data, err := json.Marshal(message)
	if err != nil {
		return err
	}

	req, err := http.NewRequest("POST", os.Getenv("SLACK_WEBHOOK"), bytes.NewBuffer(data))
	if err != nil {
		return err
	}

	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		fmt.Println(resp.StatusCode)
		return err
	}

	return nil
}

func main() {
	lambda.Start(handler)
}
