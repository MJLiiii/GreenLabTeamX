#!/usr/bin/env Rscript
# Normal execution is computational; --check-only is strictly non-computational.
options(stringsAsFactors=FALSE,warn=1)
if(.Platform$OS.type=="windows") invisible(Sys.setlocale("LC_CTYPE","English_United States.utf8"))
args<-commandArgs(trailingOnly=TRUE)
value<-function(key,default=NULL) {
  i<-match(key,args);if(is.na(i)) return(default)
  if(i==length(args)||startsWith(args[i+1L],"--")) stop("Missing value for ",key,call.=FALSE)
  args[i+1L]
}
known<-c("--root","--config","--out","--reference","--check-only","--compare-history")
if(any(startsWith(args,"--") & !args %in% known)) stop("Unknown command-line option",call.=FALSE)
file_arg<-commandArgs()[startsWith(commandArgs(),"--file=")][1L]
script<-normalizePath(sub("^--file=","",file_arg),winslash="/",mustWork=TRUE)
default_root<-dirname(dirname(dirname(script)))
root<-normalizePath(value("--root",default_root),winslash="/",mustWork=TRUE)
for(p in c("jsonlite","digest")) if(!requireNamespace(p,quietly=TRUE)) stop("Missing bootstrap R package: ",p,call.=FALSE)
stage<-file.path(root,"analysis/portable_20261018")
source(file.path(stage,"runtime.R"),encoding="UTF-8")
source(file.path(stage,"entry.R"),encoding="UTF-8")
configuration<-value("--config","analysis/portable_20261018/config.json")
config<-jsonlite::fromJSON(portable_path(root,configuration))
result<-portable_dispatch(root,config,out=value("--out"),check_only="--check-only" %in% args,
  compare_history="--compare-history" %in% args,reference=value("--reference"))
if("--check-only" %in% args) {
  print(result$packages,row.names=FALSE)
  cat("CHECK ONLY: passed; computation not started; no output created.\n")
  cat("Required assets:",result$required_assets,"; required input paths:",result$required_inputs,"\n")
}
