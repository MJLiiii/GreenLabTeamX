# Integration-only checks. Existing scientific algorithms/tests are not replaced.
snapshot_integration_files <- function(root, exclude=character()) {
  paths<-list.files(root,recursive=TRUE,all.files=TRUE,full.names=TRUE,no..=TRUE)
  paths<-gsub("\\\\","/",paths)
  rel<-substring(paths,nchar(root)+2L)
  # Only the actual repository metadata is excluded. Historical synthetic .git
  # fixtures are research/analysis artifacts and remain protected.
  keep<-!startsWith(rel,".git/")
  for(p in exclude) keep<-keep & !startsWith(tolower(paths),paste0(tolower(p),"/")) & tolower(paths)!=tolower(p)
  paths<-sort(paths[keep],method="radix")
  data.frame(path=substring(paths,nchar(root)+2L),size=as.numeric(file.info(paths)$size),
    sha256=vapply(paths,digest::digest,character(1),algo="sha256",file=TRUE,serialize=FALSE),stringsAsFactors=FALSE)
}

integration_gate <- function(q, s, r, idle, resources, issues) {
  q <- data.table::copy(q); s <- data.table::copy(s)
  q[, query_id := as.character(query_id)]; s[, query_id := as.character(query_id)]
  rows <- list()
  gate <- function(id, pass, detail) {
    rows[[length(rows) + 1L]] <<- data.table::data.table(check_id=id, passed=isTRUE(pass),detail=detail)
    if (!isTRUE(pass)) stop("Integration gate failed: ", id)
  }
  gate("counts_keys", nrow(q)==10000 && nrow(s)==2000 && nrow(r)==55 && nrow(idle)==5 && nrow(resources)==55 &&
    !anyDuplicated(q[,.(benchmark,strategy,repetition,query_id)]) && !anyDuplicated(s[,.(benchmark,strategy,query_id)]),
    "10000 query-repeat, 2000 question-strategy, 55 run, 5 idle; unique keys")
  expected <- q$run_id=="012_small_only__mmlu_pro__rep4" & q$query_id=="3030"
  special <- s$benchmark=="mmlu_pro" & s$strategy=="small_only" & s$query_id=="3030"
  gate("unique_energy_missing", sum(expected)==1 && sum(special)==1 &&
    all(vapply(c("gpu_trapezoid_j","gpu_left_j","cpu_j"),function(m)
      identical(is.na(q[[m]]),expected) && all(is.finite(q[[m]][!expected])) &&
      all(s[[paste0(m,"_n_valid")]]==ifelse(special,4L,5L)) && all(is.finite(s[[paste0(m,"_mean")]])),logical(1))) &&
    q$missing_end_ms[expected]==2 && !q$coverage_complete[expected],
    "Only approved 2 ms tail lacks complete energy; partial values never substituted; 1 cell n=4, 1999 n=5")
  gate("correct_latency_five", all(q$correct_numeric %in% c(0,1)) && all(is.finite(q$latency_ms)) &&
    all(s$correct_n_valid==5) && all(s$latency_ms_n_valid==5) && all(s$n_repetitions==5) &&
    all(s$majority_correct==(s$correct_sum>=3)), "All correctness/latency retain five; majority at least three")
  sets <- q[,.(n=.N,nq=data.table::uniqueN(query_id),nr=data.table::uniqueN(run_id)),by=.(benchmark,strategy,repetition)]
  repeats <- q[,.(n=.N,valid=setequal(repetition,1:5)),by=.(benchmark,strategy,query_id)]
  same <- all(vapply(unique(q$benchmark),function(bm){
    ref <- unique(q[benchmark==bm & strategy=="small_only",query_id])
    length(ref)==200 && all(vapply(unique(q$strategy),function(st) setequal(ref,q[benchmark==bm & strategy==st,query_id]),logical(1)))
  },logical(1)))
  gate("question_sets_repetitions",nrow(sets)==50 && all(sets$n==200 & sets$nq==200 & sets$nr==1) &&
       all(repeats$n==5 & repeats$valid) && same,"Benchmark-specific 200-question sets and five repetitions retained")
  gate("processing_reconciliation",nrow(issues)==0 && sum(r$initial_duplicate_removed)==48 &&
    all(vapply(c("gpu_trapezoid","gpu_left","cpu"),function(m)
      all(r[[paste0(m,"_reconciliation_pass")]]) &&
      all(abs(r[[paste0(m,"_reconciliation_error_j")]])<=r[[paste0(m,"_tolerance_j")]]),logical(1))),
    "Existing reconciliation invariants pass; no processing issues; exactly 48 known initialization duplicates")
  data.table::rbindlist(rows)
}

compare_result_tables <- function(actual, reference, keys, label, config) {
  a <- data.table::copy(data.table::as.data.table(actual)); b <- data.table::copy(data.table::as.data.table(reference))
  stopifnot(all(keys %in% names(a)),all(keys %in% names(b)))
  for(k in keys) {data.table::set(a,j=k,value=as.character(a[[k]])); data.table::set(b,j=k,value=as.character(b[[k]]))}
  if(anyDuplicated(a[,..keys]) || anyDuplicated(b[,..keys])) stop("Duplicate comparison key: ",label)
  data.table::setorderv(a,keys);data.table::setorderv(b,keys)
  if(nrow(a)!=nrow(b) || !identical(as.data.frame(a[,..keys]),as.data.frame(b[,..keys]))) stop("Comparison keys differ: ",label)
  fields <- intersect(names(a),names(b)); checks <- list()
  for(f in fields) {
    x<-a[[f]];y<-b[[f]]
    numeric_field <- (is.numeric(x) || is.integer(x)) && (is.numeric(y) || is.integer(y))
    if(numeric_field) {
      na_equal <- identical(is.na(x),is.na(y))
      valid <- !is.na(x) & !is.na(y)
      delta <- abs(x[valid]-y[valid])
      pfield <- f %in% c("p_raw","p_holm","primary_p_raw","primary_p_holm")
      at <- if(pfield) config$near_zero_p_absolute_tolerance else config$absolute_tolerance
      rt <- if(pfield) config$near_zero_p_relative_tolerance else config$relative_tolerance
      tol <- at+rt*abs(y[valid])
      pass <- na_equal && all(is.finite(x[valid])) && all(is.finite(y[valid])) && all(delta<=tol)
      maxerr <- if(length(delta)) max(delta) else 0
    } else {
      canon <- function(z) {z<-as.character(z);z[is.na(z)]<-"<NA>";z}
      pass <- identical(canon(x),canon(y));maxerr<-NA_real_
      at<-rt<-NA_real_
    }
    checks[[length(checks)+1L]]<-data.table::data.table(table=label,field=f,rows=nrow(a),passed=pass,
      max_absolute_difference=maxerr,absolute_tolerance=at,relative_tolerance=rt)
  }
  data.table::rbindlist(checks)
}

run_integration_tests <- function(config) {
  # Only new join/tolerance logic is tested; no repeated integration/inference fixtures.
  a<-data.table::data.table(id=c("b","a"),v=c(2,1),flag=c(FALSE,TRUE))
  b<-a[2:1]
  rows<-list()
  add<-function(id,pass) rows[[length(rows)+1L]]<<-data.table::data.table(test_id=id,passed=isTRUE(pass))
  add("key_order_independent",all(compare_result_tables(a,b,"id","synthetic",config)$passed))
  b$v[1]<-b$v[1]+config$absolute_tolerance/2
  add("declared_tolerance",all(compare_result_tables(a,b,"id","synthetic",config)$passed))
  b$v[1]<-10
  add("changed_numeric_detected",!all(compare_result_tables(a,b,"id","synthetic",config)$passed))
  b<-data.table::copy(a);b$flag[1]<-!b$flag[1]
  add("changed_decision_detected",!all(compare_result_tables(a,b,"id","synthetic",config)$passed))
  b<-data.table::copy(a);b$v[1]<-NA_real_
  add("new_missing_detected",!all(compare_result_tables(a,b,"id","synthetic",config)$passed))
  add("duplicate_key_rejected",inherits(try(compare_result_tables(a,a[c(1,1)],"id","synthetic",config),silent=TRUE),"try-error"))
  data.table::rbindlist(rows)
}
