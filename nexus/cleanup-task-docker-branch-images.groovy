import org.sonatype.nexus.repository.maintenance.MaintenanceService
import org.sonatype.nexus.repository.storage.Query
import org.sonatype.nexus.repository.storage.StorageFacet
import org.sonatype.nexus.repository.Repository
import com.google.common.collect.ImmutableList
import org.joda.time.DateTime
import java.util.regex.Pattern


/*
* Script based on https://github.com/maxout123/nexus-docker-cleanup
* Keith Douglas
* November 2019
*/

log.info(":::Cleanup script started!")

// Loop through each nexus repo
repository.repositoryManager.browse().each { Repository myRepo ->
	// Retention rules and regex to match against images
    def retentionDays = 90
    def retentionCount = 0
    def pattern = ~/^([a-zA-Z]+)_/
	// this regex only matches feature branch/pull request images, not alpha, beta, develop or master
    def patternSemver = ~/^\d+\.\d+\.\d+-(feature|bugfix|PullRequest|[A-Z]+.*)/ 
    def whitelist = ["org.javaee7.sample/javaee7-simple-sample", "org.javaee7.next/javaee7-another-sample"].toArray()

    log.info("Repository: $myRepo");
    def repositoryName = myRepo.name
	// Skip if it isn't a docker repo
    if (myRepo.getFormat().toString() != 'docker') return

	log.info("""
		*** Proceeding with repository: $repositoryName
		retentionDays: ${retentionDays}
		retentionCount: ${retentionCount}
		pattern: ${pattern}
		patternSemver: ${patternSemver}
		""")

    def alterRetention = [:]

    //alterRetention['etr_s7middleware_docker'] = [retentionCount: 30]
    //alterRetention['etr_ncenter_docker'] = [pattern: ~/^\d+\.\d+\.\d+-([a-zA-Z0-9-]+)/]
    //alterRetention['etr_s7common_docker'] = [retentionCount: 30]

    if(alterRetention.containsKey(repositoryName)){
        def alter = alterRetention[repositoryName] as Map
        log.info("Altering retention params: ${alter}")
        if(alter.containsKey('retentionDays')){
            retentionDays = alter['retentionDays'] as Integer
        }
        if(alter.containsKey('retentionCount')){
            retentionCount = alter['retentionCount'] as Integer
        }
        if(alter.containsKey('pattern')){
            pattern = alter['pattern'] as Pattern
        }
    }

	// Get all the docker images in this repo
    MaintenanceService service = container.lookup("org.sonatype.nexus.repository.maintenance.MaintenanceService") as MaintenanceService
    def repo = repository.repositoryManager.get(repositoryName)
    def tx = repo.facet(StorageFacet.class).txSupplier().get()
    def components = null
    try {
        tx.begin()
        components = ImmutableList.copyOf(tx.findComponents(Query.builder().suffix(' ORDER BY name ASC, last_updated ASC').build(), [repo]))
    }catch(Exception e){
        log.info("Error: "+e)
    }finally{
        if(tx!=null)
            tx.close()
    }

    if(components != null && components.size() > 0) {
        def retentionDate = DateTime.now().minusDays(retentionDays).dayOfMonth().roundFloorCopy()
        int deletedComponentCount = 0
        int compCount = 0
        def listOfComponents = components
        def tagCount = [:]

        def previousComp = listOfComponents.head().group() + listOfComponents.head().name()

        listOfComponents.reverseEach{comp ->			
			if(!whitelist.contains(comp.group()+"/"+comp.name())){

				if(previousComp != (comp.group() + comp.name())) {
					compCount = 0
					tagCount = [:]
					previousComp = comp.group() + comp.name()
					// log.info("group: ${comp.group()}, ${comp.name()}")
				}
				// always skip latest, don't want to delete that :)
				if(comp.version() == 'latest'){
					log.info("    version: ${comp.version()}, skipping")
					return
				}

				// Check if the image matches the regex pattern
				def prefix = null
				def matcher = comp.version() =~ pattern
				if(matcher) {
					log.info("Pattern matched against ${pattern}")
					prefix = matcher.group(1)
				} else{
					matcher = comp.version() =~ patternSemver
					if(matcher) {
						log.info("Pattern matched against semver ${patternSemver}")
						prefix = matcher.group(1)
					}
				}
				// Count how many there are matching the pattern
				// This is copied from the original script, but because we use a strict pattern and the retentionCount is 0, this step is mostly defunct
				// I did remove a else condition here which also counted images which did not match the regex
				// But in our use-case, we want to ignore those entirely
				// Keith Douglas - Nov 2019
				def actualCount=0
				if(prefix != null) {
					if(tagCount[prefix] == null) {
						tagCount[prefix] = 0
					}
					tagCount[prefix]++
					actualCount = tagCount[prefix]
					// log.info("    version: ${comp.version()}, prefix: ${prefix}")
				}
				 
				// log.info("    CompCount: ${actualCount}, RetentionCount: ${retentionCount}")
				// Check the count and date conditions before deleting
				if(actualCount > retentionCount) {
					if (comp.lastUpdated().isBefore(retentionDate)) {
						// Image is older then the retention date, delete it
						
						log.info("Component date: ${comp.lastUpdated()} is before retention cut off; ${retentionDate} and count ${actualCount} > {$retentionCount} (retentionCount)")
						log.info("Deleting ${comp.name()}, version: ${comp.version()}")

						
						service.deleteComponent(repo, comp)

						deletedComponentCount++
					}
				} 
			} else{
				log.info("Component skipped because it is in whitelist: ${comp.group()} ${comp.name()}")
			}
			
        }

        log.info("Deleted Component count: ${deletedComponentCount}")
    }

}
