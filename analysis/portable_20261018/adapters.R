# Bind only known static-file literals in existing function definitions.
# No numeric expression, scoring rule or method parameter is rewritten.
portable_bind_paths <- function(fun,mapping,expected_counts=rep(1L,length(mapping)),embedded=FALSE) {
  lines<-deparse(body(fun),width.cutoff=500L)
  text<-paste(lines,collapse="\n");counts<-integer(length(mapping))
  for(i in seq_along(mapping)) {
    old<-if(embedded) names(mapping)[i] else encodeString(names(mapping)[i],quote='"')
    new<-if(embedded) unname(mapping[i]) else encodeString(unname(mapping[i]),quote='"')
    at<-gregexpr(old,text,fixed=TRUE)[[1L]];counts[i]<-if(at[1L]<0L) 0L else length(at)
    if(counts[i]!=expected_counts[i]) stop("Unexpected static path-binding count: ",names(mapping)[i],call.=FALSE)
    text<-gsub(old,new,text,fixed=TRUE)
  }
  body(fun)<-parse(text=text,keep.source=FALSE)[[1L]]
  attr(fun,"portable_path_bindings")<-data.frame(original=names(mapping),bound=unname(mapping),occurrences=counts)
  fun
}
portable_load_modules <- function(root,config) {
  env<-new.env(parent=globalenv())
  files<-c("analysis/processing_20261017_r/support.R","analysis/processing_20261017_r/process.R",
    "analysis/reproduction_20261018/checks.R","analysis/reproduction_20261018/descriptive_stage.R",
    "analysis/reproduction_20261018/sensitivity_stage.R","analysis/reproduction_20261018/inference_stage.R")
  for(p in files) {
    path<-portable_path(root,p)
    expressions<-parse(path,keep.source=FALSE,encoding="UTF-8")
    safe<-vapply(as.list(expressions),function(x) is.call(x) && identical(x[[1L]],as.name("<-")) &&
      is.call(x[[3L]]) && identical(x[[3L]][[1L]],as.name("function")),logical(1))
    if(!length(safe)||!all(safe)) stop("Module has source-time work; refused: ",p,call.=FALSE)
    source(path,local=env,encoding="UTF-8",keep.source=FALSE)
  }
  static<-config$static_directory
  env$process_all<-portable_bind_paths(env$process_all,
    setNames(paste0(static,"/initialization_registry.csv"),"analysis/validation/audit_20261017/run_validation.csv"))
  env$run_sensitivity_stage<-portable_bind_paths(env$run_sensitivity_stage,
    setNames(paste0(static,"/comparison_plan.csv"),"analysis/descriptive_20261017/planned_comparisons.csv"),expected_counts=3L,embedded=TRUE)
  env$run_inference_stage<-portable_bind_paths(env$run_inference_stage,
    setNames(c(paste0(static,"/comparison_plan.csv"),paste0(static,"/comparison_plan.csv"),paste0(static,"/method_config.json")),
      c("analysis/descriptive_20261017/planned_comparisons.csv",
        "analysis/descriptive_outputs_20261017_01/planned_comparisons.csv",
        "analysis/inference_outputs_20261017_02/inference_config.json")))
  env
}
