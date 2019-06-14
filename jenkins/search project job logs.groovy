/*
Eg:
PROJECT = "JIRA Hook - Feature Branch Delete"
SEARCH = ["VECTWO-21649", "VECTWO-27677", "VECTWO-29706", "VECTWO-29913", "VECTWO-30680", "VECTWO-30694", "VECTWO-25560"]
*/

PROJECT = ""
SEARCH = [""]

def job = Jenkins.instance.getAllItems(Job.class).find{ 
  it.name == PROJECT
}

for (build in job.builds) {
  def log = build.log
  for (item in SEARCH){
   	if (log.contains(item)) {
      println "Build ${build.id} contains ${item}"
  	}
  }
}