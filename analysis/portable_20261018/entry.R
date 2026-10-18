# Dispatch separates checks from computation. Check-only never sources pipeline.R.
portable_dispatch <- function(root,config,out=NULL,check_only=FALSE,compare_history=FALSE,reference=NULL,
                              package_probe=function(p) requireNamespace(p,quietly=TRUE),pipeline_runner=NULL) {
  if(!compare_history && !is.null(reference)) stop("--reference requires --compare-history",call.=FALSE)
  if(compare_history && is.null(reference)) stop("--compare-history requires an explicit --reference directory",call.=FALSE)
  if(!is.null(reference)) {
    if(!grepl("^([A-Za-z]:[/\\\\]|/)",reference)) reference<-file.path(root,reference)
    reference<-normalizePath(reference,winslash="/",mustWork=FALSE)
  }
  checks<-portable_preflight(root,config,out,reference,package_probe)
  if(!checks$passed) stop(paste(checks$errors,collapse="\n"),call.=FALSE)
  if(check_only) return(checks)
  if(is.null(out)) stop("Normal execution requires --out NEW_DIRECTORY",call.=FALSE)
  out<-portable_output(root,out)
  before<-portable_snapshot(root)
  input_check<-portable_verify_inputs(root,config,before)
  if(!dir.create(out)) stop("Cannot create a new output directory",call.=FALSE)
  json_new<-function(x,name) {
    p<-file.path(out,name);if(file.exists(p)) stop("Refusing overwrite: ",name)
    jsonlite::write_json(x,p,auto_unbox=TRUE,pretty=TRUE,na="null",digits=17)
  }
  completed<-FALSE
  on.exit({
    after<-portable_snapshot(root,exclude=out)
    protection<-portable_protection(before,after)
    write.csv(after,file.path(out,"protected_after.csv"),row.names=FALSE,na="NA")
    json_new(protection,"protection.json")
    json_new(list(completed=completed,protection_passed=protection$passed,history_comparison_requested=compare_history),"completion.json")
    if(!protection$passed) stop("Protected files changed; inspect protection.json",call.=FALSE)
  },add=TRUE)
  write.csv(before,file.path(out,"protected_before.csv"),row.names=FALSE)
  write.csv(input_check,file.path(out,"required_input_checks.csv"),row.names=FALSE)
  json_new(config,"configuration.json")
  writeLines(capture.output(sessionInfo()),file.path(out,"sessionInfo.txt"))
  versions<-data.frame(package=config$packages,
    version=vapply(config$packages,function(p) as.character(packageVersion(p)),character(1)))
  write.csv(versions,file.path(out,"dependencies.csv"),row.names=FALSE)
  json_new(list(command=commandArgs(),lib_paths=.libPaths(),root=root,output=out,
    historical_comparison=compare_history,reference=reference),"runtime.json")
  if(is.null(pipeline_runner)) {
    runenv<-new.env(parent=environment())
    source(portable_path(root,"analysis/portable_20261018/adapters.R"),local=runenv,encoding="UTF-8")
    source(portable_path(root,"analysis/portable_20261018/pipeline.R"),local=runenv,encoding="UTF-8")
    pipeline_runner<-runenv$portable_pipeline
  }
  value<-pipeline_runner(root,config,out,reference)
  completed<-TRUE
  invisible(value)
}
