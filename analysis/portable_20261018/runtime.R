# Path/environment checks and per-run protection. Sourcing performs no analysis.
portable_sha <- function(path) digest::digest(file=path,algo="sha256",serialize=FALSE)
portable_under <- function(path,parent) startsWith(tolower(path),paste0(tolower(parent),"/"))
portable_relative <- function(path) {
  if(length(path)!=1L || is.na(path) || !nzchar(path) || grepl("^([A-Za-z]:|[/\\\\])",path) ||
     any(strsplit(gsub("\\\\","/",path),"/",fixed=TRUE)[[1]] %in% c("..",".")))
    stop("Expected a project-relative path: ",path,call.=FALSE)
  gsub("\\\\","/",path)
}
portable_path <- function(root,relative,must_exist=TRUE) {
  p<-file.path(root,portable_relative(relative))
  if(must_exist && !file.exists(p)) stop("Missing required path: ",relative,call.=FALSE)
  if(file.exists(p)) {
    p<-normalizePath(p,winslash="/",mustWork=TRUE)
    if(!portable_under(p,root)) stop("Required path escapes project root: ",relative,call.=FALSE)
  }
  p
}
portable_output <- function(root,path) {
  if(!grepl("^([A-Za-z]:[/\\\\]|/)",path)) path<-file.path(root,path)
  if(file.exists(path)||dir.exists(path)) stop("Output exists; refusing overwrite: ",path,call.=FALSE)
  p<-file.path(normalizePath(dirname(path),winslash="/",mustWork=TRUE),basename(path))
  if(basename(p) %in% c(".","..") || !portable_under(p,file.path(root,"analysis")) ||
     portable_under(p,file.path(root,"analysis/portable_20261018")))
    stop("Output must be a fresh independent directory under analysis/",call.=FALSE)
  p
}
portable_preflight <- function(root,config,out=NULL,reference=NULL,
                               package_probe=function(p) requireNamespace(p,quietly=TRUE)) {
  root<-normalizePath(root,winslash="/",mustWork=TRUE)
  errors<-character(); asset_count<-input_count<-0L
  attempt<-function(expr) tryCatch(expr,error=function(e){errors<<-c(errors,conditionMessage(e));NULL})
  found<-vapply(config$packages,package_probe,logical(1))
  if(any(!found)) errors<-c(errors,paste0("Missing R package: ",config$packages[!found]))
  if(!is.null(out)) attempt(portable_output(root,out))
  for(p in c("main.R","runtime.R","entry.R","adapters.R","pipeline.R"))
    attempt(portable_path(root,paste0("analysis/portable_20261018/",p)))
  asset_path<-attempt(portable_path(root,config$asset_manifest))
  if(!is.null(asset_path) && requireNamespace("digest",quietly=TRUE)) {
    if(portable_sha(asset_path)!=config$asset_manifest_sha256) errors<-c(errors,"Asset manifest SHA-256 mismatch")
    assets<-read.csv(asset_path,stringsAsFactors=FALSE,check.names=FALSE)
    if(!all(c("path","sha256","role") %in% names(assets)) || anyDuplicated(assets$path))
      errors<-c(errors,"Invalid required-asset manifest")
    else for(i in seq_len(nrow(assets))) {
      p<-attempt(portable_path(root,assets$path[i]))
      if(!is.null(p) && portable_sha(p)!=assets$sha256[i]) errors<-c(errors,paste("Required asset SHA-256 mismatch:",assets$path[i]))
    }
    asset_count<-nrow(assets)
  }
  raw_path<-attempt(portable_path(root,paste0(config$static_directory,"/input_hashes.csv")))
  if(!is.null(raw_path)) {
    inputs<-read.csv(raw_path,stringsAsFactors=FALSE,check.names=FALSE)
    if(!all(c("path","sha256","bytes") %in% names(inputs)) || anyDuplicated(inputs$path) ||
       !all(startsWith(inputs$path,"results/main/"))) errors<-c(errors,"Invalid required-input hash manifest")
    else for(p in inputs$path) attempt(portable_path(root,p))
    input_count<-nrow(inputs)
  }
  if(!is.null(reference)) {
    if(!dir.exists(reference)) errors<-c(errors,paste("Missing optional reference directory:",reference))
    else for(p in portable_comparison_catalog()$path)
      if(!file.exists(file.path(reference,p))) errors<-c(errors,paste("Missing requested reference table:",p))
  }
  list(passed=!length(errors),errors=unique(errors),packages=data.frame(package=config$packages,found=found),
       root=root,required_assets=asset_count,required_inputs=input_count,
       history_comparison_requested=!is.null(reference),computations_started=FALSE,
       check_scope="Environment, static/module integrity and file paths only; no raw values, integrals, statistics or graphics")
}
portable_snapshot <- function(root,exclude=NULL) {
  paths<-list.files(root,recursive=TRUE,all.files=TRUE,full.names=TRUE,no..=TRUE)
  paths<-gsub("\\\\","/",paths);relative<-substring(paths,nchar(root)+2L)
  keep<-!startsWith(relative,".git/")
  if(!is.null(exclude)) keep<-keep & !portable_under(paths,exclude) & tolower(paths)!=tolower(exclude)
  paths<-sort(paths[keep],method="radix")
  data.frame(path=substring(paths,nchar(root)+2L),bytes=as.numeric(file.info(paths)$size),
    sha256=vapply(paths,portable_sha,character(1)),stringsAsFactors=FALSE)
}
portable_protection <- function(before,after) {
  ix<-match(before$path,after$path)
  missing<-before$path[is.na(ix)]
  valid<-which(!is.na(ix))
  changed<-before$path[valid][before$bytes[valid]!=after$bytes[ix[valid]] | before$sha256[valid]!=after$sha256[ix[valid]]]
  added<-setdiff(after$path,before$path)
  list(passed=!length(c(missing,changed,added)),protected_files=nrow(before),
       missing=missing,modified=changed,unexpected_added=added)
}
portable_verify_inputs <- function(root,config,snapshot) {
  expected<-read.csv(portable_path(root,paste0(config$static_directory,"/input_hashes.csv")),stringsAsFactors=FALSE)
  ix<-match(expected$path,snapshot$path)
  expected$passed<-!is.na(ix) & expected$sha256==snapshot$sha256[ix] & expected$bytes==snapshot$bytes[ix]
  if(!all(expected$passed)) stop("Required original input changed: ",paste(expected$path[!expected$passed],collapse=", "),call.=FALSE)
  expected
}
portable_comparison_catalog <- function() {
  processing<-c("query_metrics","question_summary","run_reconciliation","idle_summary","run_resources")
  descriptive<-c("continuous_summary","run_means","run_variability","accuracy_summary","run_accuracy",
    "routing_summary","auxiliary_summary","quality_summary","run_resources","resources_summary",
    "idle_runs","idle_variability","method_sensitivity_question","method_sensitivity_summary")
  data.frame(stage=c(rep("processing",5),rep("descriptive",14),rep("inference",4),"sensitivity"),
    name=c(processing,descriptive,"all_primary_tests","continuous_tests","accuracy_tests","hac_sensitivity","sensitivity_point_estimates"),
    path=c(paste0("processing/",processing,".csv"),paste0("descriptive/",descriptive,".csv"),
      paste0("inference/",c("all_primary_tests","continuous_tests","accuracy_tests","hac_sensitivity"),".csv"),
      "sensitivity/sensitivity_point_estimates.csv"),stringsAsFactors=FALSE)
}
