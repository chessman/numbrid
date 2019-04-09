package main

import (
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"os"
	"os/exec"
	"path"
	"strings"
	"time"
)

var (
	rootDir   = ""
	staticDir = path.Join(rootDir, "static")
	mediaDir  = path.Join(staticDir, "media")
)

var quantNominative = []string{"null", "üks", "kaks", "kolm", "neli", "viis", "kuus", "seitse", "kaheksa", "üheksa"}
var ordinalNominative = []string{"nulline", "esimene", "teine", "kolmas", "neljas", "viies", "kuues", "seitsmes", "kaneksas", "üheksas"}
var ordinalGenitive = []string{"nullise", "esimese", "teise", "kolmanda", "neljanda", "viienda", "kuuenda", "seitsmenda", "kaneksanda", "üheksanda"}
var ordinalPrefs = []string{"", "ühe", "kahe", "kolme", "nelja", "viie", "kuue", "seitsme", "kaheksa", "üheksa"}

func quantitiveNominativeUpTo100(n int) string {
	if n < 10 {
		return quantNominative[n]
	}

	if n == 10 {
		return "kümme"
	}

	if n < 20 {
		return quantNominative[n%10] + "teist"
	}

	if n < 100 {
		if n%10 == 0 {
			return quantNominative[n/10] + "kümmend"
		}
		return quantNominative[n/10] + "kümmend " + quantNominative[n%10]
	}
	return "liiga rohkem"
}

func ordinalNominativeUpTo100(n int) string {
	if n < 10 {
		return ordinalNominative[n]
	}

	if n == 10 {
		return "kümnes"
	}

	if n < 20 {
		return ordinalPrefs[n%10] + "teistkümnes"
	}

	if n < 100 {
		if n%10 == 0 {
			return ordinalPrefs[n/10] + "kümnes"
		}
		return ordinalPrefs[n/10] + "kümne " + ordinalNominative[n%10]
	}
	return "liiga rohkem"
}

func ordinalGenitiveUpTo100(n int) string {
	if n < 10 {
		return ordinalGenitive[n]
	}

	if n == 10 {
		return "kümnenda"
	}

	if n < 20 {
		return ordinalPrefs[n%10] + "teistkümnenda"
	}

	if n < 100 {
		if n%10 == 0 {
			return ordinalPrefs[n/10] + "kümnenda"
		}
		return ordinalPrefs[n/10] + "kümne " + ordinalGenitive[n%10]
	}
	return "liiga rohkem"
}

func ordinalAdessiveUpTo100(n int) string {
	return ordinalGenitiveUpTo100(n) + "l"
}

func randN() int {
	rand.Seed(time.Now().UnixNano())
	n := rand.Intn(20 + 80*rand.Intn(2))
	if n == 0 {
		return randN()
	}
	return n
}

func wget(name, mp3file string) {
	escaped := strings.Replace(name, " ", "+", -1)
	url := fmt.Sprintf("http://translate.google.com/translate_tts?ie=UTF-8&total=1&idx=0&textlen=32&client=tw-ob&q=%s&tl=et", escaped)
	err := exec.Command("wget", "-q", "-U", "Mozilla", "-O", mp3file, url).Run()
	if err != nil {
		panic(err)
	}
}

func ensureDirs() {
	os.MkdirAll(staticDir, 0755)
	os.MkdirAll(mediaDir, 0755)
}

func fileDownloader(h http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
		h.ServeHTTP(w, req)
	})
}

type Response struct {
	N                    int
	QuantitiveNominative string
	OrdinalNominative    string
	OrdinalGenitive      string
	OrdinalAdessive      string
}

func cacheMpsFile(name string) {
	mp3file := path.Join(mediaDir, name+".mp3")
	if _, err := os.Stat(mp3file); os.IsNotExist(err) {
		wget(name, mp3file)
	}
}

func cacheMp3Files(resp Response) {
	cacheMpsFile(resp.OrdinalAdessive)
	cacheMpsFile(resp.OrdinalNominative)
	cacheMpsFile(resp.QuantitiveNominative)
}

func next(w http.ResponseWriter, req *http.Request) {
	defer req.Body.Close()
	n := randN()
	resp := Response{
		N:                    n,
		QuantitiveNominative: quantitiveNominativeUpTo100(n),
		OrdinalNominative:    ordinalNominativeUpTo100(n),
		OrdinalGenitive:      ordinalGenitiveUpTo100(n),
		OrdinalAdessive:      ordinalAdessiveUpTo100(n),
	}
	cacheMp3Files(resp)

	respJson, _ := json.Marshal(resp)
	w.Write(respJson)
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		log.Fatal("$PORT must be set")
	}
	ensureDirs()
	fs := http.FileServer(http.Dir("static"))
	http.Handle("/next", http.HandlerFunc(next))
	http.Handle("/", fileDownloader(fs))
	log.Println("Listening...")
	err := http.ListenAndServe(":"+port, nil)
	if err != nil {
		panic(err)
	}
}
