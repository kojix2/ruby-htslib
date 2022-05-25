# c2ffi

* Docker file for [c2ffi](https://github.com/rpav/c2ffi)

Usage

```sh
docker build -t c2ffi .
docker run -v $(pwd):/data c2ffi sam.h
```

Extract function names

```sh
docker run -v $(pwd):/data c2ffi bgzf.h ¥
  | ruby -rjson -e "JSON[ARGF.read].filter{|l| l['tag'] == 'function'}.each{|l| puts l['name']}"
docker run -v $(pwd):/data c2ffi bgzf.h | jq '.[] | select(.tag == "function")["name"]'
```

Top keys

```sh
docker run -v $(pwd):/data c2ffi sam.h ¥
  | ruby -rjson -e "puts JSON[ARGF.read].map{|l| l.keys}.flatten" ¥
  | uplot count
```

```console
                 ┌                                        ┐ 
        location ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 801.0   
            name ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 801.0   
              ns ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 801.0   
             tag ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 801.0   
          inline ┤■■■■■■■■■■■■■■■■■■■■■ 511.0               
      parameters ┤■■■■■■■■■■■■■■■■■■■■■ 511.0               
     return-type ┤■■■■■■■■■■■■■■■■■■■■■ 511.0               
   storage-class ┤■■■■■■■■■■■■■■■■■■■■■ 511.0               
        variadic ┤■■■■■■■■■■■■■■■■■■■■■ 511.0               
            type ┤■■■■■■■■■ 230.0                           
          fields ┤■■ 60.0                                   
              id ┤■■ 60.0                                   
   bit-alignment ┤■■ 52.0                                   
        bit-size ┤■■ 52.0                                   
                 └                                        ┘ 

```

## Location

```sh
docker run -v $(pwd):/data c2ffi sam.h ¥
  | ruby -rjson -e "puts JSON[ARGF.read].map{|l| l['location']}.flatten" ¥
  | cut -f2 -d: ¥
  | uplot hist -n 30
```

```console
                    ┌                                        ┐ 
   [   0.0,  100.0) ┤▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇ 170   
   [ 100.0,  200.0) ┤▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇ 129           
   [ 200.0,  300.0) ┤▇▇▇▇▇▇▇▇▇▇▇▇ 60                           
   [ 300.0,  400.0) ┤▇▇▇▇▇▇▇▇ 41                               
   [ 400.0,  500.0) ┤▇▇▇▇▇▇▇▇▇▇▇▇▇▇ 70                         
   [ 500.0,  600.0) ┤▇▇▇▇▇▇▇▇▇ 43                              
   [ 600.0,  700.0) ┤▇▇▇▇▇▇▇▇ 37                               
   [ 700.0,  800.0) ┤▇▇▇▇▇▇▇ 35                                
   [ 800.0,  900.0) ┤▇▇▇▇▇▇▇▇▇ 43                              
   [ 900.0, 1000.0) ┤▇▇▇▇▇ 25                                  
   [1000.0, 1100.0) ┤▇▇▇ 13                                    
   [1100.0, 1200.0) ┤▇▇▇▇ 17                                   
   [1200.0, 1300.0) ┤▇▇ 10                                     
   [1300.0, 1400.0) ┤▇▇▇▇ 19                                   
   [1400.0, 1500.0) ┤▇▇▇▇ 20                                   
   [1500.0, 1600.0) ┤▇▇ 11                                     
   [1600.0, 1700.0) ┤▇ 6                                       
   [1700.0, 1800.0) ┤▇ 6                                       
   [1800.0, 1900.0) ┤▇ 4                                       
   [1900.0, 2000.0) ┤▇▇▇▇ 21                                   
   [2000.0, 2100.0) ┤▇▇ 12                                     
   [2100.0, 2200.0) ┤▇ 5                                       
   [2200.0, 2300.0) ┤▇ 4                                       
                    └                                        ┘ 
                                    Frequency

```

## tags

```sh
docker run -v $(pwd):/data c2ffi sam.h ¥
  | ruby -rjson -e "puts JSON[ARGF.read].map{|l| l['tag']}.flatten" ¥
  | uplot count
```

```console
            ┌                                        ┐ 
   function ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 511.0   
    typedef ┤■■■■■■■■■■■■■■ 222.0                      
     struct ┤■■■ 51.0                                  
       enum ┤■ 8.0                                     
     extern ┤■ 8.0                                     
      union ┤ 1.0                                      
            └                                        ┘ 

```

## Function

```sh
docker run -v $(pwd):/data c2ffi hts.h | jq '.[] | select(.name=="hts_open")'
```

```json
{
  "tag": "function",
  "name": "hts_open",
  "ns": 0,
  "location": "hts.h:601:10",
  "variadic": false,
  "inline": false,
  "storage-class": "none",
  "parameters": [
    {
      "tag": "parameter",
      "name": "fn",
      "type": {
        "tag": ":pointer",
        "type": {
          "tag": ":char",
          "bit-size": 8,
          "bit-alignment": 8
        }
      }
    },
    {
      "tag": "parameter",
      "name": "mode",
      "type": {
        "tag": ":pointer",
        "type": {
          "tag": ":char",
          "bit-size": 8,
          "bit-alignment": 8
        }
      }
    }
  ],
  "return-type": {
    "tag": ":pointer",
    "type": {
      "tag": "htsFile"
    }
  }
}
```

