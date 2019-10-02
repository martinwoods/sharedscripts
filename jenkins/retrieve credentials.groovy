def credentials_store = jenkins.model.Jenkins.instance.getExtensionList(
        'com.cloudbees.plugins.credentials.SystemCredentialsProvider'
        )

//println "credentials_store: ${credentials_store}"
//credentials_store.each {  println "credentials_store.each: ${it}" }

credentials_store[0].credentials.each { it ->
    if (it instanceof com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl) {
        println "${it.id}: username: ${it.username} password: ${it.password} description: ${it.description}"
    } else if (it instanceof org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl){
      println "${it.id}: secret: ${it.secret}  description: ${it.description}"
    }
}
return true