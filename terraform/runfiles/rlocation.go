package main

import (
	"context"

	"github.com/bazelbuild/rules_go/go/runfiles"
	"github.com/hashicorp/terraform-plugin-framework/function"
	"github.com/hashicorp/terraform-plugin-framework/types"
)

type rlocationFunction struct{}

func NewRlocationFunction() function.Function {
	return &rlocationFunction{}
}

func (f *rlocationFunction) Metadata(_ context.Context, _ function.MetadataRequest, resp *function.MetadataResponse) {
	resp.Name = "rlocation"
}

func (f *rlocationFunction) Definition(_ context.Context, _ function.DefinitionRequest, resp *function.DefinitionResponse) {
	resp.Definition = function.Definition{
		Summary:     "Resolve a runfiles path using Bazel's rlocation algorithm",
		Description: "Given an apparent path, resolves the path using Bazel's repo mapping and runfiles.",
		Parameters: []function.Parameter{
			function.StringParameter{
				Name:        "path",
				Description: "The apparent path (e.g., workspace_name/path/to/file)",
			},
		},
		Return: function.StringReturn{},
	}
}

func (f *rlocationFunction) Run(ctx context.Context, req function.RunRequest, resp *function.RunResponse) {
	var path string
	resp.Error = function.ConcatFuncErrors(
		req.Arguments.Get(ctx, &path),
	)
	if resp.Error != nil {
		return
	}

	result, err := runfiles.RlocationFrom(path, "")
	if err != nil {
		resp.Error = function.NewFuncError(err.Error())
		return
	}

	resp.Error = resp.Result.Set(ctx, types.StringValue(result))
}

type rlocationFromFunction struct{}

func NewRlocationFromFunction() function.Function {
	return &rlocationFromFunction{}
}

func (f *rlocationFromFunction) Metadata(_ context.Context, _ function.MetadataRequest, resp *function.MetadataResponse) {
	resp.Name = "rlocation_from"
}

func (f *rlocationFromFunction) Definition(_ context.Context, _ function.DefinitionRequest, resp *function.DefinitionResponse) {
	resp.Definition = function.Definition{
		Summary:     "Resolve a runfiles path using Bazel's rlocation algorithm",
		Description: "Given an apparent path and requesting repository, resolves the path using Bazel's repo mapping and runfiles.",
		Parameters: []function.Parameter{
			function.StringParameter{
				Name:        "path",
				Description: "The apparent path (e.g., workspace_name/path/to/file)",
			},
			function.StringParameter{
				Name:        "source_repo",
				Description: "The canonical path of the requesting repository",
			},
		},
		Return: function.StringReturn{},
	}
}

func (f *rlocationFromFunction) Run(ctx context.Context, req function.RunRequest, resp *function.RunResponse) {
	var path, sourceRepo string
	resp.Error = function.ConcatFuncErrors(
		req.Arguments.Get(ctx, &path, &sourceRepo),
	)
	if resp.Error != nil {
		return
	}

	result, err := runfiles.RlocationFrom(path, sourceRepo)
	if err != nil {
		resp.Error = function.NewFuncError(err.Error())
		return
	}

	resp.Error = resp.Result.Set(ctx, types.StringValue(result))
}
