package sms

import (
	"errors"
	"fmt"
	"log/slog"

	"github.com/huaweicloud/huaweicloud-sdk-go-v3/core/def"
	smsapi "github.com/huaweicloud/huaweicloud-sdk-go-v3/services/smsapi/v1"
	"github.com/huaweicloud/huaweicloud-sdk-go-v3/services/smsapi/v1/model"
	"github.com/huaweicloud/huaweicloud-sdk-go-v3/services/smsapi/v1/region"
)

var ErrUnavailable = errors.New("sms provider is not configured")

type Sender interface {
	SendCode(phone, code string) error
}

type Disabled struct{}

func (Disabled) SendCode(string, string) error { return ErrUnavailable }

type Mock struct {
	Logger *slog.Logger
}

func (m Mock) SendCode(phone, code string) error {
	if m.Logger != nil {
		m.Logger.Info("mock sms code", "phone", phone, "code", code)
	}
	return nil
}

type Huawei struct {
	client    *smsapi.SMSApiClient
	from      string
	template  string
	signature string
}

func NewHuawei(
	appKey, appSecret, from, templateID, signature, regionID string,
) (*Huawei, error) {
	if appKey == "" || appSecret == "" || from == "" || templateID == "" {
		return nil, ErrUnavailable
	}
	if regionID == "" {
		regionID = "cn-north-4"
	}
	credentials := smsapi.NewSMSApiCredentialsBuilder().
		WithAk(appKey).
		WithSk(appSecret).
		Build()
	client, err := smsapi.SMSApiClientBuilder().
		WithRegion(region.ValueOf(regionID)).
		WithCredential(credentials).
		SafeBuild()
	if err != nil {
		return nil, fmt.Errorf("create Huawei SMS client: %w", err)
	}
	return &Huawei{
		client: smsapi.NewSMSApiClient(client), from: from,
		template: templateID, signature: signature,
	}, nil
}

func (h *Huawei) SendCode(phone, code string) error {
	request := &model.BatchSendSmsRequest{
		Body: &model.BatchSendSmsRequestBody{
			From:          def.NewMultiPart(h.from),
			To:            def.NewMultiPart(phone),
			TemplateId:    def.NewMultiPart(h.template),
			TemplateParas: def.NewMultiPart(fmt.Sprintf("[\"%s\"]", code)),
			Signature:     def.NewMultiPart(h.signature),
		},
	}
	response, err := h.client.BatchSendSms(request)
	if err != nil {
		return fmt.Errorf("send Huawei SMS: %w", err)
	}
	if response == nil {
		return errors.New("send Huawei SMS: empty response")
	}
	if response.HttpStatusCode != 200 {
		return fmt.Errorf("send Huawei SMS: HTTP %d", response.HttpStatusCode)
	}
	if response.Code != nil && *response.Code != "000000" {
		description := ""
		if response.Description != nil {
			description = *response.Description
		}
		return fmt.Errorf("send Huawei SMS: %s %s", *response.Code, description)
	}
	return nil
}
