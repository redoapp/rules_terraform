package main

import (
	"context"

	"github.com/hashicorp/terraform-plugin-framework/datasource"
	"github.com/hashicorp/terraform-plugin-framework/function"
	"github.com/hashicorp/terraform-plugin-framework/provider"
	"github.com/hashicorp/terraform-plugin-framework/resource"
)

type runfilesProvider struct{}

func New() provider.Provider {
	return &runfilesProvider{}
}

func (p *runfilesProvider) Metadata(_ context.Context, _ provider.MetadataRequest, resp *provider.MetadataResponse) {
	resp.TypeName = "runfiles"
}

func (p *runfilesProvider) Schema(_ context.Context, _ provider.SchemaRequest, _ *provider.SchemaResponse) {
}

func (p *runfilesProvider) Configure(_ context.Context, _ provider.ConfigureRequest, _ *provider.ConfigureResponse) {
}

func (p *runfilesProvider) Resources(_ context.Context) []func() resource.Resource {
	return nil
}

func (p *runfilesProvider) DataSources(_ context.Context) []func() datasource.DataSource {
	return nil
}

func (p *runfilesProvider) Functions(_ context.Context) []func() function.Function {
	return []func() function.Function{
		NewRlocationFunction,
		NewRlocationFromFunction,
	}
}
