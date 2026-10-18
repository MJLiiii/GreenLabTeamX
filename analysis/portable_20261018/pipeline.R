# Existing scientific functions are reused; only orchestration/paths are adapted.
# This file is NOT sourced by --check-only. No pipeline is executed on import.
portable_pipeline <- function(root,config,out,reference=NULL) {
  library(data.table)
  data.table::setDTthreads(1L)
  modules<-portable_load_modules(root,config)
  read<-function(path) data.table::fread(path,na.strings="NA",integer64="double",encoding="UTF-8")
  write<-function(x,name) modules$csv_new(x,file.path(out,name))
  static<-portable_path(root,config$static_directory)
  plan<-read(file.path(static,"comparison_plan.csv"))
  methods<-jsonlite::fromJSON(file.path(static,"method_config.json"))
  bindings<-data.table::rbindlist(lapply(c("process_all","run_sensitivity_stage","run_inference_stage"),function(n) {
    z<-attr(modules[[n]],"portable_path_bindings");z$function_name<-n;z
  }))
  write(bindings,"static_path_bindings.csv")
  processing<-file.path(out,"processing");dir.create(processing)
  modules$process_all(root,processing)
  q<-read(file.path(processing,"query_metrics.csv"));s<-read(file.path(processing,"question_summary.csv"))
  r<-read(file.path(processing,"run_reconciliation.csv"));idle<-read(file.path(processing,"idle_summary.csv"))
  resources<-read(file.path(processing,"run_resources.csv"));issues<-read(file.path(processing,"processing_issues.csv"))
  write(modules$integration_gate(q,s,r,idle,resources,issues),"integration_gates.csv")
  descriptive<-modules$run_descriptive_stage(root,processing,file.path(out,"descriptive"))
  modules$run_sensitivity_stage(root,processing,file.path(out,"sensitivity"),plan)
  inference<-modules$run_inference_stage(root,processing,file.path(out,"sensitivity"),file.path(out,"inference"),plan,methods)
  if(!is.null(reference)) {
    catalog<-portable_comparison_catalog();comparisons<-list()
    for(i in seq_len(nrow(catalog))) {
      a<-read(file.path(out,catalog$path[i]));b<-read(file.path(reference,catalog$path[i]))
      if(!identical(names(a),names(b))) stop("Reference schema differs: ",catalog$path[i])
      keys<-if(catalog$stage[i]=="inference") {
        if(catalog$name[i]=="hac_sensitivity") c("comparison_id","lag") else "comparison_id"
      } else if(catalog$stage[i]=="sensitivity") c("specification_id","scenario") else
        intersect(c("benchmark","strategy","metric","repetition","run_id","query_id","final_model"),names(a))
      comparisons[[i]]<-modules$compare_result_tables(a,b,keys,catalog$path[i],config)
    }
    comparisons<-data.table::rbindlist(comparisons)
    write(comparisons,"history_comparisons.csv")
    if(!all(comparisons$passed)) stop("Requested historical comparison failed")
  }
  both<-function(zh,en) c(paste0("中文：",zh),"",paste0("English: ",en),"")
  note<-c("# 普通复现结果 / Reproduction result","",
    both("所有表来自本次原始输入计算；历史数值对照仅在显式指定时执行。方法与批准规范不变。依赖、来源、检查和保护结果在本目录记录。",
      "All tables are calculated from current original inputs. Numerical historical comparison is performed only when explicitly requested. Approved methods are unchanged; dependencies, provenance, checks and protection are recorded here."),
    paste0("History comparison requested / 已请求历史对照: ",!is.null(reference)),"",
    "[Processing](processing/query_metrics.csv) · [Question summaries](processing/question_summary.csv)","",
    "[Primary tests](inference/all_primary_tests.csv) · [HAC](inference/hac_sensitivity.csv)","",
    "[Figures / 图表](figures_index.md) · [Protection / 保护](protection.json)")
  modules$text_new(note,file.path(out,"README.md"))
  lines<-c("# 图表索引 / Figure index","",
    both("图表使用本次计算结果；推断区间为未调整逐比较95%，Holm判断单独显示。",
      "Figures use this run's calculations; inferential intervals are unadjusted pointwise 95% with separate Holm decisions."))
  for(kind in c("descriptive","inference")) {
    index<-if(kind=="descriptive") descriptive$figure_index else inference$figures
    for(i in seq_len(nrow(index))) lines<-c(lines,paste0("## ",index$figure_id[i]),"",
      paste0("[PNG](",kind,"/",index$png[i],") · [PDF](",kind,"/",index$pdf[i],")"),"",
      both(index$description_zh[i],index$description_en[i]))
  }
  modules$text_new(lines,file.path(out,"figures_index.md"))
  invisible(list(query_rows=nrow(q),question_rows=nrow(s),primary_rows=nrow(inference$primary),hac_rows=nrow(inference$hac)))
}
