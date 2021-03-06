# devtools::load_all("fhi")
fhi::DashboardInitialiseOpinionated(
  NAME = "sykdomspulspdf",
  PKG = "sykdomspulspdf",
  PACKAGE_DIR = "."
)

suppressMessages(library(data.table))
suppressMessages(library(ggplot2))


files <- list.files(fhi::DashboardFolder("data_raw"), "^partially_formatted_")
mydate <- format(Sys.time(), "%d.%m.%y")

# fhi::DashboardIsDev()
fhi::DashboardMsg("/data_raw")
list.files("/data_raw")

fhi::DashboardMsg("/data_raw/sykdomspulspdf")
list.files("/data_raw/sykdomspulspdf")

if (length(files) == 0) {
  fhi::DashboardMsg("No data")
  quit(save = "no", status = 0)
} else {
  for (f in files) fhi::DashboardMsg(f)
  # grab the latest
  useFile <- max(files)

  if (file.exists(fhi::DashboardFolder("results", "DONE.txt")) & !fhi::DashboardIsDev()) {
    fhi::DashboardMsg("results DONE.txt exists")
    quit(save = "no", status = 0)
  }

  if (RAWmisc::IsFileStable(fhi::DashboardFolder("data_raw", useFile)) == F) {
    fhi::DashboardMsg("file no stable")
    quit(save = "no", status = 0)
  }



  d <- fread(fhi::DashboardFolder("data_raw", useFile))
  fylke <- fread(system.file("extdata", "fylke.csv", package = "sykdomspulspdf"))
  lastestUpdate <- as.Date(gsub("_", "-", LatestRawID()))


  fhi::DashboardMsg("Generating monthly pdf")


  allfylkeresults <- list()
  allfylkeresultsdata <- list()
  allfylke <- NULL
  mylistyrange <- list()

  for (SYNDROM in CONFIG$SYNDROMES) {
    sykdompulspdf_template_copy(fhi::DashboardFolder("data_raw"), SYNDROM)
    # sykdompulspdf_template_copy_ALL(fhi::DashboardFolder("data_raw"), SYNDROM)
    fhi::sykdompulspdf_resources_copy(fhi::DashboardFolder("data_raw"))

    if (SYNDROM == "mage") {
      add <- "magetarm"
      mytittle <- "Mage-tarminfeksjoner"

      # Alle konsultasjoner in Norway:
      data <- CleanData(d)
      alle <- tapply(data$gastro, data[, c("year", "week")], sum)
      weeknow <- findLastWeek(lastestUpdate, alle) ### need to be fixed

      if (weeknow==30) {
        weeknow <-29
      }

      title="Mage-tarminfeksjoner, Norge, alle aldersgrupper"
      yrange <- max(alle, na.rm = T) + (roundUpNice(max(alle, na.rm = T)) * .20)

      svg(filename=fhi::DashboardFolder("results", paste("gastro Norge alle alder", Sys.Date(), "svg", sep = ".")),
          width = 16, height = 12
      )
      CreatePlotsNorway(d = alle, weeknow = weeknow, Ukenummer = Ukenummer, title, yrange)
      dev.off()


      # Alle konsultasjoner in Norway by age:
      svg(filename=fhi::DashboardFolder("results", paste("gastro Norge Aldersfordelt", Sys.Date(), "svg", sep = ".")),
          width = 16, height = 12
      )
      CreatePlotsNorwayByAge(d1 = data, weeknow = weeknow, Ukenummer = Ukenummer, Fylkename = f, S = SYNDROM, mytittle = mytittle)
      dev.off()
    } else if (SYNDROM == "luft") {
      add <- "luftvei"
      mytittle <- "Luftveisinfeksjoner"

      # Alle konsultasjoner in Norway:
      data <- CleanData(d)
      alle <- tapply(data$respiratory, data[, c("year", "week")], sum)

      title="Luftveisinfeksjoner, Norge, alle aldersgrupper"

      yrange <- max(alle, na.rm = T) + (roundUpNice(max(alle, na.rm = T)) * .20)

      svg(filename=fhi::DashboardFolder("results", paste("respiratory Norge alle alder", Sys.Date(), "svg", sep = ".")),
          width = 16, height = 12
      )
      CreatePlotsNorway(d = alle, weeknow = weeknow, Ukenummer = Ukenummer, title, yrange)
      dev.off()

      # Alle konsultasjoner in Norway by age:
      svg(filename=fhi::DashboardFolder("results", paste("respiratory Norge Aldersfordelt", Sys.Date(), "svg", sep = ".")),
          width = 16, height = 12
      )
      CreatePlotsNorwayByAge(d1 = data, weeknow = weeknow, Ukenummer = Ukenummer, Fylkename = f, S = SYNDROM, mytittle = mytittle)
      dev.off()
    }

    ###########################################
    typetemplate <- fread(fhi::DashboardFolder("data_raw", paste("typetemplate_", SYNDROM, ".txt", sep = "")))
    ## BY FYLKE
    for (f in fylke$Fylkename) {
      fhi::DashboardMsg(sprintf("PDF: %s", f))


      Fylkename <- f
      data <- CleanDataByFylke(d, fylke, f)
      alle <- tapply(getdataout(data, SYNDROM), data[, c("year", "week")], sum)

      allfylkeresults[[f]] <- alle
      allfylkeresultsdata[[f]] <- data
      allfylke <- c(allfylke, f)

      yrange <- max(alle, na.rm = T) + (roundUpNice(max(alle, na.rm = T)) * .20)
      mylistyrange[[f]] <- yrange

      # fhi::RenderExternally()

      nametemplate <- unique(typetemplate[V1 == f, V3])
      childtemplate <- unique(typetemplate[V1 == f, V4])

      rmarkdown::render(
        input = fhi::DashboardFolder("data_raw", paste(nametemplate, SYNDROM, ".Rmd", sep = "")),
        output_file = paste(gsub(" ", "", f, fixed = TRUE), "_", add, ".pdf", sep = ""),
        output_dir = fhi::DashboardFolder("results", paste("PDF", mydate, sep = "_"))
      )
    }
    rmarkdown::render(
      input = fhi::DashboardFolder("data_raw", paste("monthly_report_", SYNDROM, "ALL.Rmd", sep = "")),
      output_file = paste("ALL", "_", add, ".pdf", sep = ""),
      output_dir = fhi::DashboardFolder("results", paste("PDF", mydate, sep = "_"))
    )


    sykdompulspdf_template_remove(fhi::DashboardFolder("data_raw"), SYNDROM)
    # sykdompulspdf_template_remove_ALL(fhi::DashboardFolder("data_raw"), SYNDROM)
  }

  fhi::sykdompulspdf_resources_remove(fhi::DashboardFolder("data_raw"))
}

file.create(fhi::DashboardFolder("results", "DONE.txt"))
if (!fhi::DashboardIsDev()) quit(save = "no", status = 0)
